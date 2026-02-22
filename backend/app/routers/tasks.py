"""
업무 + 중간보고 라우터
"""
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from uuid import uuid4
from ..database import get_db
from ..models import User, Task, Report, TaskStatus
from ..schemas import (
    TaskCreate, TaskUpdate, TaskOut,
    ReportCreate, ReportUpdate, ReportOut,
    DailyReportDept, DeptOut,
)
from ..auth import get_current_user

router = APIRouter(prefix="/tasks", tags=["tasks"])


# ── 업무 목록 ──────────────────────────────────────────
@router.get("/", response_model=list[TaskOut])
async def list_tasks(
    dept_id    : str | None = Query(None),
    status     : str | None = Query(None),
    include_hidden: bool    = Query(False, description="True면 숨긴 항목도 포함"),
    _          : User       = Depends(get_current_user),
    db         : AsyncSession = Depends(get_db),
):
    q = select(Task).options(selectinload(Task.reports))
    if dept_id: q = q.where(Task.dept_id == dept_id)
    if status:  q = q.where(Task.status  == status)
    if not include_hidden:
        q = q.where(Task.is_hidden == False)
    q = q.order_by(Task.created_at.desc())
    result = await db.execute(q)
    return [TaskOut.model_validate(t) for t in result.scalars()]


# ── 업무 생성 ──────────────────────────────────────────
@router.post("/", response_model=TaskOut)
async def create_task(
    body   : TaskCreate,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    task = Task(
        id=str(uuid4()),
        title=body.title.strip(),
        description=body.description,
        dept_id=body.dept_id,
        department_ids=body.department_ids,
        status=body.status,
        priority=body.priority,
        assignee_name=body.assignee_name,
        assignee_ids=body.assignee_ids,
        start_date=body.start_date,
        due_date=body.due_date,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    # reports 로드
    result = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task.id)
    )
    return TaskOut.model_validate(result.scalar_one())


# ── 업무 수정 ──────────────────────────────────────────
@router.patch("/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: str,
    body   : TaskUpdate,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")

    if body.title         is not None: task.title         = body.title.strip()
    if body.description   is not None: task.description   = body.description
    if body.dept_id       is not None: task.dept_id       = body.dept_id
    if body.department_ids is not None: task.department_ids = body.department_ids
    if body.status        is not None: task.status        = body.status
    if body.priority      is not None: task.priority      = body.priority
    if body.assignee_name is not None: task.assignee_name = body.assignee_name
    if body.assignee_ids  is not None: task.assignee_ids  = body.assignee_ids
    if body.start_date    is not None: task.start_date    = body.start_date
    if body.due_date      is not None: task.due_date      = body.due_date
    task.updated_at = datetime.utcnow()

    await db.commit()
    result2 = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    return TaskOut.model_validate(result2.scalar_one())


# ── 업무 상태만 변경 ───────────────────────────────────
@router.patch("/{task_id}/status", response_model=TaskOut)
async def update_status(
    task_id: str,
    body   : dict,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")
    task.status     = body.get("status", task.status)
    task.updated_at = datetime.utcnow()
    await db.commit()
    result2 = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    return TaskOut.model_validate(result2.scalar_one())


# ── 완료 업무 숨기기 (보관함엔 유지) ─────────────────
@router.patch("/{task_id}/hide", response_model=TaskOut)
async def hide_task(
    task_id: str,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")
    if task.status != TaskStatus.done:
        raise HTTPException(status_code=400, detail="완료 상태인 업무만 숨길 수 있습니다.")
    task.is_hidden  = True
    task.hidden_at  = datetime.utcnow()
    task.updated_at = datetime.utcnow()
    await db.commit()
    result2 = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    return TaskOut.model_validate(result2.scalar_one())


# ── 숨긴 업무 복원 ─────────────────────────────────────
@router.patch("/{task_id}/unhide", response_model=TaskOut)
async def unhide_task(
    task_id: str,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")
    task.is_hidden  = False
    task.hidden_at  = None
    task.updated_at = datetime.utcnow()
    await db.commit()
    result2 = await db.execute(
        select(Task).options(selectinload(Task.reports)).where(Task.id == task_id)
    )
    return TaskOut.model_validate(result2.scalar_one())


# ── 완료 업무 보관함 조회 (숨긴 항목 포함, 날짜별 정렬) ─
@router.get("/archive", response_model=list[TaskOut])
async def list_archive(
    dept_id : str | None = Query(None),
    _       : User        = Depends(get_current_user),
    db      : AsyncSession = Depends(get_db),
):
    """완료된 모든 업무 (숨긴 것 포함) 최신순 반환"""
    q = (
        select(Task)
        .options(selectinload(Task.reports))
        .where(Task.status == TaskStatus.done)
    )
    if dept_id:
        q = q.where(Task.dept_id == dept_id)
    q = q.order_by(Task.updated_at.desc())
    result = await db.execute(q)
    return [TaskOut.model_validate(t) for t in result.scalars()]


# ── 업무 삭제 (영구) ─────────────────────────────────────
@router.delete("/{task_id}")
async def delete_task(
    task_id: str,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task   = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")
    await db.delete(task)
    await db.commit()
    return {"ok": True}


# ── 중간보고 추가 ──────────────────────────────────────
@router.post("/{task_id}/reports", response_model=ReportOut)
async def add_report(
    task_id: str,
    body   : ReportCreate,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Task).where(Task.id == task_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="업무를 찾을 수 없습니다.")
    now = datetime.utcnow()
    report = Report(
        id=str(uuid4()), task_id=task_id,
        content=body.content, reporter_name=body.reporter_name,
        created_at=now, updated_at=now,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return ReportOut.model_validate(report)


# ── 중간보고 수정 ──────────────────────────────────────
@router.patch("/{task_id}/reports/{report_id}", response_model=ReportOut)
async def update_report(
    task_id  : str,
    report_id: str,
    body     : ReportUpdate,
    current  : User = Depends(get_current_user),
    db       : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.task_id == task_id)
    )
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="보고를 찾을 수 없습니다.")
    if body.content       is not None: report.content       = body.content
    if body.reporter_name is not None: report.reporter_name = body.reporter_name
    report.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(report)
    return ReportOut.model_validate(report)


# ── 중간보고 삭제 ──────────────────────────────────────
@router.delete("/{task_id}/reports/{report_id}")
async def delete_report(
    task_id  : str,
    report_id: str,
    current  : User = Depends(get_current_user),
    db       : AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.task_id == task_id)
    )
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="보고를 찾을 수 없습니다.")
    await db.delete(report)
    await db.commit()
    return {"ok": True}


# ── 일일 보고 데이터 ───────────────────────────────────
@router.get("/daily-report", response_model=list[DailyReportDept])
async def daily_report(
    date   : str = Query(..., description="YYYY-MM-DD"),
    _      : User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    from ..models import Department
    try:
        target = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="날짜 형식은 YYYY-MM-DD 입니다.")

    depts_result = await db.execute(select(Department).order_by(Department.created_at))
    depts = depts_result.scalars().all()

    result_list = []
    for dept in depts:
        # 해당 날짜에 완료되었거나 보고가 있는 업무
        q = (
            select(Task)
            .options(selectinload(Task.reports))
            .where(Task.dept_id == dept.id)
        )
        tasks_result = await db.execute(q)
        all_tasks    = tasks_result.scalars().all()

        day_tasks = []
        for t in all_tasks:
            is_done = t.status == TaskStatus.done
            has_report = any(
                r.created_at.year  == target.year and
                r.created_at.month == target.month and
                r.created_at.day   == target.day
                for r in t.reports
            )
            if is_done or has_report:
                day_tasks.append(t)

        if day_tasks:
            result_list.append(DailyReportDept(
                dept =DeptOut.model_validate(dept),
                tasks=[TaskOut.model_validate(t) for t in day_tasks],
            ))

    return result_list
