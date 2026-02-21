"""
부서 관리 라우터
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import uuid4
from ..database import get_db
from ..models import User, Department, Task
from ..schemas import DeptCreate, DeptUpdate, DeptOut
from ..auth import get_current_user

router = APIRouter(prefix="/departments", tags=["departments"])


@router.get("/", response_model=list[DeptOut])
async def list_depts(
    _  : User = Depends(get_current_user),
    db : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Department).order_by(Department.created_at))
    return [DeptOut.model_validate(d) for d in result.scalars()]


@router.post("/", response_model=DeptOut)
async def create_dept(
    body   : DeptCreate,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    dept = Department(
        id=str(uuid4()),
        name=body.name.strip(),
        emoji=body.emoji,
        description=body.description,
        manager_name=body.manager_name,
    )
    db.add(dept)
    await db.commit()
    await db.refresh(dept)
    return DeptOut.model_validate(dept)


@router.patch("/{dept_id}", response_model=DeptOut)
async def update_dept(
    dept_id: str,
    body   : DeptUpdate,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Department).where(Department.id == dept_id))
    dept   = result.scalar_one_or_none()
    if not dept:
        raise HTTPException(status_code=404, detail="부서를 찾을 수 없습니다.")

    if body.name         is not None: dept.name         = body.name.strip()
    if body.emoji        is not None: dept.emoji        = body.emoji
    if body.description  is not None: dept.description  = body.description
    if body.manager_name is not None: dept.manager_name = body.manager_name

    await db.commit()
    await db.refresh(dept)
    return DeptOut.model_validate(dept)


@router.delete("/{dept_id}")
async def delete_dept(
    dept_id: str,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Department).where(Department.id == dept_id))
    dept   = result.scalar_one_or_none()
    if not dept:
        raise HTTPException(status_code=404, detail="부서를 찾을 수 없습니다.")
    # cascade delete-orphan 으로 관련 Task/Report 도 삭제됨
    await db.delete(dept)
    await db.commit()
    return {"ok": True}
