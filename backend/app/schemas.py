"""
Pydantic 스키마 (요청/응답 직렬화)
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from .models import UserRole, TaskStatus, TaskPriority


# ── Auth ───────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type  : str = "bearer"
    user        : "UserOut"

class ChangePasswordRequest(BaseModel):
    user_id     : str
    new_password: str


# ── User ───────────────────────────────────────────────
class UserCreate(BaseModel):
    username    : str
    password    : str
    display_name: str
    role        : UserRole = UserRole.user
    dept_id     : Optional[str] = None

class UserUpdate(BaseModel):
    username    : Optional[str] = None
    display_name: Optional[str] = None
    role        : Optional[UserRole] = None
    dept_id     : Optional[str] = None
    is_active   : Optional[bool] = None

class UserOut(BaseModel):
    id          : str
    username    : str
    display_name: str
    role        : UserRole
    dept_id     : Optional[str]
    is_active   : bool

    model_config = {"from_attributes": True}


# ── Department ─────────────────────────────────────────
class DeptCreate(BaseModel):
    name        : str
    emoji       : str = "📁"
    description : str = ""
    manager_name: Optional[str] = None

class DeptUpdate(BaseModel):
    name        : Optional[str] = None
    emoji       : Optional[str] = None
    description : Optional[str] = None
    manager_name: Optional[str] = None

class DeptOut(BaseModel):
    id          : str
    name        : str
    emoji       : str
    description : str
    manager_name: Optional[str]

    model_config = {"from_attributes": True}


# ── Report ─────────────────────────────────────────────
class ReportCreate(BaseModel):
    content      : str
    reporter_name: Optional[str] = None

class ReportUpdate(BaseModel):
    content      : Optional[str] = None
    reporter_name: Optional[str] = None

class ReportOut(BaseModel):
    id           : str
    task_id      : str
    content      : str
    reporter_name: Optional[str]
    created_at   : datetime
    updated_at   : datetime

    model_config = {"from_attributes": True}


# ── Task ───────────────────────────────────────────────
class TaskCreate(BaseModel):
    title          : str
    description    : str = ""
    dept_id        : str
    department_ids : Optional[str] = None   # JSON: '["dept1","dept2"]' or '["__ALL__"]'
    status         : TaskStatus    = TaskStatus.notStarted
    priority       : TaskPriority  = TaskPriority.medium
    assignee_name  : Optional[str] = None
    assignee_ids   : Optional[str] = None   # JSON: '["id1","id2"]'
    start_date     : Optional[datetime] = None
    due_date       : Optional[datetime] = None

class TaskUpdate(BaseModel):
    title          : Optional[str]         = None
    description    : Optional[str]         = None
    dept_id        : Optional[str]         = None
    department_ids : Optional[str]         = None
    status         : Optional[TaskStatus]  = None
    priority       : Optional[TaskPriority]= None
    assignee_name  : Optional[str]         = None
    assignee_ids   : Optional[str]         = None   # JSON: '["id1","id2"]'
    start_date     : Optional[datetime]    = None
    due_date       : Optional[datetime]    = None

class TaskOut(BaseModel):
    id             : str
    title          : str
    description    : str
    dept_id        : str
    department_ids : Optional[str] = None
    status         : TaskStatus
    priority       : TaskPriority
    assignee_name  : Optional[str]
    assignee_ids   : Optional[str] = None   # JSON: '["id1","id2"]'
    start_date     : Optional[datetime]
    due_date       : Optional[datetime]
    created_at     : datetime
    updated_at     : datetime
    is_hidden      : bool = False
    hidden_at      : Optional[datetime] = None
    reports        : list[ReportOut] = []

    model_config = {"from_attributes": True}


# ── Daily Report ───────────────────────────────────────
class DailyReportTask(BaseModel):
    task   : TaskOut
    reports: list[ReportOut]

class DailyReportDept(BaseModel):
    dept : DeptOut
    tasks: list[TaskOut]

# 순환참조 해결
TokenResponse.model_rebuild()


# ── DailyRecord (일일 보관함) ──────────────────────────
class DailyRecordOut(BaseModel):
    id          : str
    date        : str
    summary_json: str
    total_tasks : int
    done_count  : int
    in_progress : int
    not_started : int
    dept_count  : int
    saved_by    : str
    created_at  : datetime
    updated_at  : datetime

    model_config = {"from_attributes": True}


class DailyRecordListItem(BaseModel):
    """목록 조회용 (summary_json 제외 - 용량 절약)"""
    id          : str
    date        : str
    total_tasks : int
    done_count  : int
    in_progress : int
    not_started : int
    dept_count  : int
    saved_by    : str
    created_at  : datetime

    model_config = {"from_attributes": True}
