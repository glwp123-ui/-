"""
데이터 백업 / 복원 라우터
- GET  /backup/export  : 전체 데이터를 JSON으로 다운로드 (master 전용)
- POST /backup/import  : JSON 데이터를 서버에 복원 (master 전용)
  * 기존 데이터는 삭제하지 않고 없는 것만 추가 (upsert)
"""
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from ..database import get_db
from ..models import User, Department, Task, Report, UserRole, TaskStatus, TaskPriority
from ..auth import get_current_user, require_master
from ..backup_manager import save_backup

router = APIRouter(prefix="/backup", tags=["backup"])


def _dt(s):
    """문자열을 datetime으로 안전하게 변환"""
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00").replace("+00:00", ""))
    except Exception:
        return None


# ── 전체 데이터 내보내기 ─────────────────────────────
@router.get("/export")
async def export_all(
    _master: User = Depends(require_master),
    db: AsyncSession = Depends(get_db),
):
    """전체 DB 데이터를 JSON으로 반환 (master 전용)"""
    users_r = await db.execute(select(User).order_by(User.created_at))
    depts_r = await db.execute(select(Department).order_by(Department.created_at))
    tasks_r = await db.execute(select(Task).order_by(Task.created_at))
    reports_r = await db.execute(select(Report).order_by(Report.created_at))

    def u2d(u: User):
        return {
            "id": u.id, "username": u.username, "password": u.password,
            "display_name": u.display_name, "role": u.role.value,
            "dept_id": u.dept_id, "is_active": u.is_active,
            "created_at": u.created_at.isoformat() if u.created_at else None,
        }

    def d2d(d: Department):
        return {
            "id": d.id, "name": d.name, "emoji": d.emoji,
            "description": d.description, "manager_name": d.manager_name,
            "created_at": d.created_at.isoformat() if d.created_at else None,
        }

    def t2d(t: Task):
        return {
            "id": t.id, "title": t.title, "description": t.description,
            "dept_id": t.dept_id, "department_ids": t.department_ids,
            "status": t.status.value, "priority": t.priority.value,
            "assignee_name": t.assignee_name, "assignee_ids": t.assignee_ids,
            "start_date": t.start_date.isoformat() if t.start_date else None,
            "due_date": t.due_date.isoformat() if t.due_date else None,
            "is_hidden": t.is_hidden,
            "hidden_at": t.hidden_at.isoformat() if t.hidden_at else None,
            "created_at": t.created_at.isoformat() if t.created_at else None,
            "updated_at": t.updated_at.isoformat() if t.updated_at else None,
        }

    def r2d(r: Report):
        return {
            "id": r.id, "task_id": r.task_id, "content": r.content,
            "reporter_name": r.reporter_name,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "updated_at": r.updated_at.isoformat() if r.updated_at else None,
        }

    payload = {
        "exported_at": datetime.utcnow().isoformat(),
        "users": [u2d(u) for u in users_r.scalars()],
        "departments": [d2d(d) for d in depts_r.scalars()],
        "tasks": [t2d(t) for t in tasks_r.scalars()],
        "reports": [r2d(r) for r in reports_r.scalars()],
    }
    return JSONResponse(content=payload)


# ── 데이터 복원 (upsert) ────────────────────────────
@router.post("/import")
async def import_all(
    payload: dict,
    _master: User = Depends(require_master),
    db: AsyncSession = Depends(get_db),
):
    """
    JSON 데이터를 DB에 복원합니다.
    기존 ID와 같은 항목은 업데이트, 없는 항목은 새로 추가합니다.
    """
    stats = {"users": 0, "departments": 0, "tasks": 0, "reports": 0}

    # ── 부서 복원
    for d in payload.get("departments", []):
        existing = await db.get(Department, d["id"])
        if existing:
            existing.name = d["name"]
            existing.emoji = d.get("emoji", "📁")
            existing.description = d.get("description", "")
            existing.manager_name = d.get("manager_name")
        else:
            db.add(Department(
                id=d["id"], name=d["name"],
                emoji=d.get("emoji", "📁"),
                description=d.get("description", ""),
                manager_name=d.get("manager_name"),
                created_at=_dt(d.get("created_at")) or datetime.utcnow(),
            ))
        stats["departments"] += 1

    await db.flush()

    # ── 사용자 복원
    for u in payload.get("users", []):
        existing = await db.get(User, u["id"])
        role = UserRole(u.get("role", "user"))
        if existing:
            existing.username = u["username"]
            existing.password = u["password"]   # 해시 그대로 보존
            existing.display_name = u["display_name"]
            existing.role = role
            existing.dept_id = u.get("dept_id")
            existing.is_active = u.get("is_active", True)
        else:
            db.add(User(
                id=u["id"], username=u["username"],
                password=u["password"],
                display_name=u["display_name"],
                role=role,
                dept_id=u.get("dept_id"),
                is_active=u.get("is_active", True),
                created_at=_dt(u.get("created_at")) or datetime.utcnow(),
            ))
        stats["users"] += 1

    await db.flush()

    # ── 업무 복원
    for t in payload.get("tasks", []):
        existing = await db.get(Task, t["id"])
        status   = TaskStatus(t.get("status", "notStarted"))
        priority = TaskPriority(t.get("priority", "medium"))
        if existing:
            existing.title          = t["title"]
            existing.description    = t.get("description", "")
            existing.dept_id        = t["dept_id"]
            existing.department_ids = t.get("department_ids")
            existing.status         = status
            existing.priority       = priority
            existing.assignee_name  = t.get("assignee_name")
            existing.assignee_ids   = t.get("assignee_ids")
            existing.start_date     = _dt(t.get("start_date"))
            existing.due_date       = _dt(t.get("due_date"))
            existing.is_hidden      = t.get("is_hidden", False)
            existing.hidden_at      = _dt(t.get("hidden_at"))
            existing.updated_at     = _dt(t.get("updated_at")) or datetime.utcnow()
        else:
            db.add(Task(
                id=t["id"], title=t["title"],
                description=t.get("description", ""),
                dept_id=t["dept_id"],
                department_ids=t.get("department_ids"),
                status=status, priority=priority,
                assignee_name=t.get("assignee_name"),
                assignee_ids=t.get("assignee_ids"),
                start_date=_dt(t.get("start_date")),
                due_date=_dt(t.get("due_date")),
                is_hidden=t.get("is_hidden", False),
                hidden_at=_dt(t.get("hidden_at")),
                created_at=_dt(t.get("created_at")) or datetime.utcnow(),
                updated_at=_dt(t.get("updated_at")) or datetime.utcnow(),
            ))
        stats["tasks"] += 1

    await db.flush()

    # ── 보고 복원
    for r in payload.get("reports", []):
        existing = await db.get(Report, r["id"])
        if existing:
            existing.content       = r["content"]
            existing.reporter_name = r.get("reporter_name")
            existing.updated_at    = _dt(r.get("updated_at")) or datetime.utcnow()
        else:
            db.add(Report(
                id=r["id"], task_id=r["task_id"],
                content=r["content"],
                reporter_name=r.get("reporter_name"),
                created_at=_dt(r.get("created_at")) or datetime.utcnow(),
                updated_at=_dt(r.get("updated_at")) or datetime.utcnow(),
            ))
        stats["reports"] += 1

    await db.commit()
    # 복원 후 즉시 백업 파일 갱신
    await save_backup(db)
    return {"ok": True, "restored": stats}


# ── 현재 DB를 파일로 즉시 저장 ────────────────────────
@router.post("/save")
async def save_now(
    _master: User = Depends(require_master),
    db: AsyncSession = Depends(get_db),
):
    """현재 DB 상태를 backup.json 파일로 즉시 저장 (master 전용)"""
    from ..backup_manager import BACKUP_PATH
    ok = await save_backup(db)
    return {
        "ok": ok,
        "backup_file": str(BACKUP_PATH),
        "backup_exists": BACKUP_PATH.exists(),
        "backup_size_bytes": BACKUP_PATH.stat().st_size if BACKUP_PATH.exists() else 0,
    }
