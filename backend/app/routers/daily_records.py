"""
일일 보관함 라우터
- 매일 자정 자동 저장 (scheduler)
- 수동 저장 (POST /daily-records/save)
- 목록 조회 (GET /daily-records/)
- 상세 조회 (GET /daily-records/{date})
- 삭제     (DELETE /daily-records/{date})
"""
import json
from datetime import datetime, date as dt_date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from uuid import uuid4

from ..database import get_db
from ..models import User, Task, Department, Report, DailyRecord, TaskStatus
from ..schemas import DailyRecordOut, DailyRecordListItem
from ..auth import get_current_user

router = APIRouter(prefix="/daily-records", tags=["daily-records"])


# ── 핵심: 특정 날짜의 업무 현황을 JSON으로 빌드 ────────
async def _build_record_data(target_date: dt_date, db: AsyncSession) -> dict:
    """
    target_date 기준으로
      - 완료된 모든 업무
      - 해당 날짜에 보고가 있는 진행 중 업무
    를 부서별로 묶어 JSON 구조를 반환
    """
    depts_result = await db.execute(select(Department).order_by(Department.created_at))
    depts = depts_result.scalars().all()

    dept_list = []
    total_tasks = 0
    done_count = 0
    in_progress_count = 0
    not_started_count = 0

    for dept in depts:
        q = (
            select(Task)
            .options(selectinload(Task.reports))
            .where(Task.dept_id == dept.id)
        )
        tasks_result = await db.execute(q)
        all_tasks = tasks_result.scalars().all()

        day_tasks = []
        for t in all_tasks:
            is_done = t.status == TaskStatus.done
            has_report_today = any(
                r.created_at.year  == target_date.year  and
                r.created_at.month == target_date.month and
                r.created_at.day   == target_date.day
                for r in t.reports
            )
            if is_done or has_report_today:
                day_tasks.append(t)

        if day_tasks:
            tasks_json = []
            for t in day_tasks:
                today_reports = [
                    {
                        "id": r.id,
                        "content": r.content,
                        "reporter_name": r.reporter_name,
                        "created_at": r.created_at.isoformat(),
                    }
                    for r in t.reports
                    if r.created_at.year  == target_date.year  and
                       r.created_at.month == target_date.month and
                       r.created_at.day   == target_date.day
                ]
                tasks_json.append({
                    "id"           : t.id,
                    "title"        : t.title,
                    "description"  : t.description,
                    "status"       : t.status.value,
                    "priority"     : t.priority.value,
                    "assignee_name": t.assignee_name,
                    "due_date"     : t.due_date.isoformat() if t.due_date else None,
                    "reports"      : today_reports,
                })
                total_tasks += 1
                if t.status.value == "done":
                    done_count += 1
                elif t.status.value == "inProgress":
                    in_progress_count += 1
                else:
                    not_started_count += 1

            dept_list.append({
                "dept_id"     : dept.id,
                "dept_name"   : dept.name,
                "dept_emoji"  : dept.emoji,
                "manager_name": dept.manager_name,
                "tasks"       : tasks_json,
            })

    return {
        "date"        : target_date.isoformat(),
        "departments" : dept_list,
        "total_tasks" : total_tasks,
        "done_count"  : done_count,
        "in_progress" : in_progress_count,
        "not_started" : not_started_count,
        "dept_count"  : len(dept_list),
    }


# ── 내부 저장 함수 (자동/수동 공용) ──────────────────
async def _upsert_record(
    target_date: dt_date,
    saved_by: str,
    db: AsyncSession,
) -> DailyRecord:
    data = await _build_record_data(target_date, db)

    # 이미 있으면 덮어쓰기
    result = await db.execute(
        select(DailyRecord).where(DailyRecord.date == data["date"])
    )
    record = result.scalar_one_or_none()

    if record:
        record.summary_json = json.dumps(data, ensure_ascii=False)
        record.total_tasks  = data["total_tasks"]
        record.done_count   = data["done_count"]
        record.in_progress  = data["in_progress"]
        record.not_started  = data["not_started"]
        record.dept_count   = data["dept_count"]
        record.saved_by     = saved_by
        record.updated_at   = datetime.utcnow()
    else:
        record = DailyRecord(
            id           = str(uuid4()),
            date         = data["date"],
            summary_json = json.dumps(data, ensure_ascii=False),
            total_tasks  = data["total_tasks"],
            done_count   = data["done_count"],
            in_progress  = data["in_progress"],
            not_started  = data["not_started"],
            dept_count   = data["dept_count"],
            saved_by     = saved_by,
            created_at   = datetime.utcnow(),
            updated_at   = datetime.utcnow(),
        )
        db.add(record)

    await db.commit()
    await db.refresh(record)
    return record


# ── 수동 저장 (오늘 or 특정 날짜) ─────────────────────
@router.post("/save", response_model=DailyRecordOut)
async def save_record(
    target_date: str | None = Query(None, description="YYYY-MM-DD (기본값: 오늘)"),
    current    : User = Depends(get_current_user),
    db         : AsyncSession = Depends(get_db),
):
    """오늘(또는 지정 날짜)의 업무 현황을 보관함에 저장"""
    if target_date:
        try:
            parsed = datetime.strptime(target_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="날짜 형식은 YYYY-MM-DD 입니다.")
    else:
        parsed = datetime.utcnow().date()

    record = await _upsert_record(parsed, "manual", db)
    return DailyRecordOut.model_validate(record)


# ── 목록 조회 ──────────────────────────────────────────
@router.get("/", response_model=list[DailyRecordListItem])
async def list_records(
    limit  : int = Query(60, ge=1, le=365),
    offset : int = Query(0, ge=0),
    _      : User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    """저장된 보관함 목록 (최신순)"""
    q = (
        select(DailyRecord)
        .order_by(DailyRecord.date.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(q)
    return [DailyRecordListItem.model_validate(r) for r in result.scalars()]


# ── 상세 조회 (날짜로) ─────────────────────────────────
@router.get("/{record_date}", response_model=DailyRecordOut)
async def get_record(
    record_date: str,
    _          : User = Depends(get_current_user),
    db         : AsyncSession = Depends(get_db),
):
    """특정 날짜의 보관함 상세 내용"""
    result = await db.execute(
        select(DailyRecord).where(DailyRecord.date == record_date)
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=404, detail="해당 날짜의 보관 기록이 없습니다.")
    return DailyRecordOut.model_validate(record)


# ── 삭제 ───────────────────────────────────────────────
@router.delete("/{record_date}")
async def delete_record(
    record_date: str,
    current    : User = Depends(get_current_user),
    db         : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DailyRecord).where(DailyRecord.date == record_date)
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=404, detail="해당 날짜의 보관 기록이 없습니다.")
    await db.delete(record)
    await db.commit()
    return {"ok": True}
