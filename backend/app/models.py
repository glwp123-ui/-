"""
SQLAlchemy ORM 모델 (테이블 정의)
"""
from datetime import datetime
from sqlalchemy import (
    String, Integer, Boolean, DateTime, Text,
    ForeignKey, Enum as SAEnum
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum
from .database import Base


class UserRole(str, enum.Enum):
    master = "master"
    admin  = "admin"
    user   = "user"


class TaskStatus(str, enum.Enum):
    notStarted = "notStarted"
    inProgress = "inProgress"
    done       = "done"


class TaskPriority(str, enum.Enum):
    low    = "low"
    medium = "medium"
    high   = "high"


# ── 사용자 ─────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id          : Mapped[str]  = mapped_column(String(36), primary_key=True)
    username    : Mapped[str]  = mapped_column(String(50), unique=True, nullable=False)
    password    : Mapped[str]  = mapped_column(String(200), nullable=False)  # bcrypt hash
    display_name: Mapped[str]  = mapped_column(String(100), nullable=False)
    role        : Mapped[UserRole] = mapped_column(SAEnum(UserRole), default=UserRole.user)
    dept_id     : Mapped[str | None] = mapped_column(String(36), ForeignKey("departments.id"), nullable=True)
    is_active   : Mapped[bool] = mapped_column(Boolean, default=True)
    created_at  : Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# ── 부서 ───────────────────────────────────────────────
class Department(Base):
    __tablename__ = "departments"

    id          : Mapped[str]  = mapped_column(String(36), primary_key=True)
    name        : Mapped[str]  = mapped_column(String(100), nullable=False)
    emoji       : Mapped[str]  = mapped_column(String(10), default="📁")
    description : Mapped[str]  = mapped_column(Text, default="")
    manager_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at  : Mapped[datetime]   = mapped_column(DateTime, default=datetime.utcnow)

    tasks: Mapped[list["Task"]] = relationship("Task", back_populates="department",
                                               cascade="all, delete-orphan")


# ── 업무 ───────────────────────────────────────────────
class Task(Base):
    __tablename__ = "tasks"

    id           : Mapped[str]  = mapped_column(String(36), primary_key=True)
    title        : Mapped[str]  = mapped_column(String(200), nullable=False)
    description  : Mapped[str]  = mapped_column(Text, default="")
    dept_id      : Mapped[str]  = mapped_column(String(36), ForeignKey("departments.id"), nullable=False)
    status       : Mapped[TaskStatus]   = mapped_column(SAEnum(TaskStatus),   default=TaskStatus.notStarted)
    priority     : Mapped[TaskPriority] = mapped_column(SAEnum(TaskPriority), default=TaskPriority.medium)
    assignee_name: Mapped[str | None]   = mapped_column(String(100), nullable=True)
    start_date   : Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    due_date     : Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_hidden    : Mapped[bool] = mapped_column(Boolean, default=False)  # 완료 후 보드에서 숨김 (보관함엔 유지)
    hidden_at    : Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # 숨긴 일시
    created_at   : Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at   : Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    department: Mapped["Department"] = relationship("Department", back_populates="tasks")
    reports   : Mapped[list["Report"]] = relationship("Report", back_populates="task",
                                                      cascade="all, delete-orphan")


# ── 중간보고 ───────────────────────────────────────────
class Report(Base):
    __tablename__ = "reports"

    id           : Mapped[str]  = mapped_column(String(36), primary_key=True)
    task_id      : Mapped[str]  = mapped_column(String(36), ForeignKey("tasks.id"), nullable=False)
    content      : Mapped[str]  = mapped_column(Text, nullable=False)
    reporter_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at   : Mapped[datetime]   = mapped_column(DateTime, default=datetime.utcnow)
    updated_at   : Mapped[datetime]   = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    task: Mapped["Task"] = relationship("Task", back_populates="reports")
