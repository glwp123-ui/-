"""
사용자 관리 라우터 (마스터 전용)
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import uuid4
from ..database import get_db
from ..models import User, UserRole
from ..schemas import UserCreate, UserUpdate, UserOut
from ..auth import hash_password, get_current_user, require_master
from ..backup_manager import save_backup

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/", response_model=list[UserOut])
async def list_users(
    _  : User = Depends(get_current_user),   # 로그인 필요
    db : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).order_by(User.created_at))
    return [UserOut.model_validate(u) for u in result.scalars()]


@router.post("/", response_model=UserOut)
async def create_user(
    body   : UserCreate,
    _master: User = Depends(require_master),
    db     : AsyncSession = Depends(get_db),
):
    exists = await db.execute(select(User).where(User.username == body.username.strip()))
    if exists.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="이미 사용 중인 아이디입니다.")
    if not body.username.strip():
        raise HTTPException(status_code=400, detail="아이디를 입력하세요.")
    if not body.password.strip():
        raise HTTPException(status_code=400, detail="비밀번호를 입력하세요.")
    if not body.display_name.strip():
        raise HTTPException(status_code=400, detail="이름을 입력하세요.")

    user = User(
        id=str(uuid4()),
        username=body.username.strip(),
        password=hash_password(body.password.strip()),
        display_name=body.display_name.strip(),
        role=body.role,
        dept_id=body.dept_id,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    await save_backup(db)
    return UserOut.model_validate(user)


@router.patch("/{user_id}", response_model=UserOut)
async def update_user(
    user_id: str,
    body   : UserUpdate,
    master : User = Depends(require_master),
    db     : AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user   = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    # username 중복 체크
    if body.username is not None:
        dup = await db.execute(
            select(User).where(User.username == body.username, User.id != user_id)
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="이미 사용 중인 아이디입니다.")
        user.username = body.username.strip()

    if body.display_name is not None: user.display_name = body.display_name.strip()
    if body.role         is not None: user.role         = body.role
    if body.dept_id      is not None: user.dept_id      = body.dept_id
    if body.is_active    is not None: user.is_active    = body.is_active

    await db.commit()
    await db.refresh(user)
    await save_backup(db)
    return UserOut.model_validate(user)


@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    master : User = Depends(require_master),
    db     : AsyncSession = Depends(get_db),
):
    if user_id == master.id:
        raise HTTPException(status_code=400, detail="현재 로그인된 계정은 삭제할 수 없습니다.")

    result = await db.execute(select(User).where(User.id == user_id))
    user   = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    # 마스터 계정 보호
    if user.role == UserRole.master:
        cnt = await db.execute(
            select(User).where(User.role == UserRole.master)
        )
        if len(cnt.scalars().all()) <= 1:
            raise HTTPException(status_code=400, detail="마스터 계정은 최소 1개 이상 유지해야 합니다.")

    await db.delete(user)
    await db.commit()
    await save_backup(db)
    return {"ok": True}
