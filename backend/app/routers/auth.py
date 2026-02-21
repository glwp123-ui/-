"""
인증 라우터: 로그인, 비밀번호 변경, 내 정보
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..database import get_db
from ..models import User
from ..schemas import LoginRequest, TokenResponse, UserOut, ChangePasswordRequest
from ..auth import verify_password, hash_password, create_token, get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User).where(User.username == body.username.strip())
    )
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    if not verify_password(body.password.strip(), user.password):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")

    token = create_token(user.id, user.role.value)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
async def me(current: User = Depends(get_current_user)):
    return UserOut.model_validate(current)


@router.post("/change-password")
async def change_password(
    body   : ChangePasswordRequest,
    current: User = Depends(get_current_user),
    db     : AsyncSession = Depends(get_db),
):
    # 마스터만 다른 사람 비밀번호 변경 가능
    if body.user_id != current.id and current.role.value != "master":
        raise HTTPException(status_code=403, detail="권한이 없습니다.")
    result = await db.execute(select(User).where(User.id == body.user_id))
    user   = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    if not body.new_password.strip():
        raise HTTPException(status_code=400, detail="새 비밀번호를 입력하세요.")
    user.password = hash_password(body.new_password.strip())
    await db.commit()
    return {"ok": True}
