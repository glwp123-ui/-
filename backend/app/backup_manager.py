"""
데이터 영속성 관리 모듈
- Render 재배포 시 DB 초기화 문제 해결
- 전략:
  1. 서버 시작 시: 코드와 함께 커밋된 data/backup.json을 읽어서 복원
  2. 데이터 변경 시: 코드 디렉토리 내 data/backup.json에 자동 저장
  3. GitHub에 backup.json을 주기적으로 커밋하면 재배포 후에도 데이터 유지
"""
import json
import os
import logging
from datetime import datetime
from pathlib import Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from .models import User, Department, Task, Report, UserRole, TaskStatus, TaskPriority

logger = logging.getLogger(__name__)

# 백업 파일 경로 결정
def _get_backup_path() -> Path:
    # 코드 디렉토리 내 data/ 폴더 (GitHub에 커밋 가능)
    code_data_dir = Path(__file__).parent.parent / "data"
    code_data_dir.mkdir(parents=True, exist_ok=True)
    return code_data_dir / "backup.json"

BACKUP_PATH = _get_backup_path()


def _dt(s):
    """문자열 → datetime 안전 변환"""
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00").replace("+00:00", ""))
    except Exception:
        return None


async def save_backup(db: AsyncSession) -> bool:
    """현재 DB 전체를 JSON 파일로 저장"""
    try:
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
            "saved_at": datetime.utcnow().isoformat(),
            "users": [u2d(u) for u in users_r.scalars()],
            "departments": [d2d(d) for d in depts_r.scalars()],
            "tasks": [t2d(t) for t in tasks_r.scalars()],
            "reports": [r2d(r) for r in reports_r.scalars()],
        }

        with open(BACKUP_PATH, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        logger.info(f"✅ 백업 저장 완료: {BACKUP_PATH} "
                    f"(사용자:{len(payload['users'])}, "
                    f"부서:{len(payload['departments'])}, "
                    f"업무:{len(payload['tasks'])})")
        return True

    except Exception as e:
        logger.error(f"❌ 백업 저장 실패: {e}")
        return False


async def restore_from_backup(db: AsyncSession) -> bool:
    """
    백업 파일이 있으면 DB에 복원 (upsert 방식 - 기존 데이터 덮어쓰기)
    시드 데이터보다 우선 적용됩니다.
    """
    if not BACKUP_PATH.exists():
        logger.info("📂 백업 파일 없음 - 시드 데이터 사용")
        return False

    try:
        with open(BACKUP_PATH, "r", encoding="utf-8") as f:
            payload = json.load(f)

        saved_at = payload.get("saved_at", "알 수 없음")
        logger.info(f"📥 백업 복원 시작 (저장 시각: {saved_at})")

        stats = {"users": 0, "departments": 0, "tasks": 0, "reports": 0}

        # 부서 복원
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

        # 사용자 복원
        for u in payload.get("users", []):
            existing = await db.get(User, u["id"])
            role = UserRole(u.get("role", "user"))
            if existing:
                existing.username = u["username"]
                existing.password = u["password"]
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

        # 업무 복원
        for t in payload.get("tasks", []):
            existing = await db.get(Task, t["id"])
            status = TaskStatus(t.get("status", "notStarted"))
            priority = TaskPriority(t.get("priority", "medium"))
            if existing:
                existing.title = t["title"]
                existing.description = t.get("description", "")
                existing.dept_id = t["dept_id"]
                existing.department_ids = t.get("department_ids")
                existing.status = status
                existing.priority = priority
                existing.assignee_name = t.get("assignee_name")
                existing.assignee_ids = t.get("assignee_ids")
                existing.start_date = _dt(t.get("start_date"))
                existing.due_date = _dt(t.get("due_date"))
                existing.is_hidden = t.get("is_hidden", False)
                existing.hidden_at = _dt(t.get("hidden_at"))
                existing.updated_at = _dt(t.get("updated_at")) or datetime.utcnow()
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

        # 보고 복원
        for r in payload.get("reports", []):
            existing = await db.get(Report, r["id"])
            if existing:
                existing.content = r["content"]
                existing.reporter_name = r.get("reporter_name")
                existing.updated_at = _dt(r.get("updated_at")) or datetime.utcnow()
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

        logger.info(f"✅ 백업 복원 완료: 사용자={stats['users']}, "
                    f"부서={stats['departments']}, 업무={stats['tasks']}, "
                    f"보고={stats['reports']}")
        return True

    except Exception as e:
        logger.error(f"❌ 백업 복원 실패: {e}")
        import traceback
        traceback.print_exc()
        return False
