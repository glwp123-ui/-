"""
JWT 인증 + 비밀번호 해시 유틸리티
"""
from datetime import datetime, timedelta, timezone
from typing import Optional
import os, hashlib, secrets
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .database import get_db
from .models import User

SECRET_KEY  = os.environ.get("SECRET_KEY", "songwork-secret-key-2025-change-in-production")
ALGORITHM   = "HS256"
TOKEN_EXPIRE_HOURS = 24 * 7  # 7일

bearer = HTTPBearer(auto_error=False)

_SALT = "sw_salt_2025"


def hash_password(plain: str) -> str:
    """SHA-256 기반 단순 해시 (소규모 내부 앱용)"""
    return hashlib.sha256(f"{_SALT}{plain}".encode()).hexdigest()

def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed

def create_token(user_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRE_HOURS)
    return jwt.encode(
        {"sub": user_id, "role": role, "exp": expire},
        SECRET_KEY, algorithm=ALGORITHM
    )

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


async def get_current_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
    db   : AsyncSession = Depends(get_db),
) -> User:
    if not creds:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = decode_token(creds.credentials)
    user_id = payload.get("sub")
    result  = await db.execute(select(User).where(User.id == user_id))
    user    = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user


def require_master(current: User = Depends(get_current_user)) -> User:
    if current.role.value != "master":
        raise HTTPException(status_code=403, detail="Master only")
    return current

def require_admin(current: User = Depends(get_current_user)) -> User:
    if current.role.value not in ("master", "admin"):
        raise HTTPException(status_code=403, detail="Admin or Master only")
    return current
