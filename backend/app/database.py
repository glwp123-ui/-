"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- 환경변수 DATABASE_URL 로 연결 (Render 환경변수에 설정)
- 로컬 개발: SQLite 폴백 (DATABASE_URL 없을 때)
"""
import os
import logging
from pathlib import Path
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)


def _build_database_url() -> str:
    """
    DATABASE_URL 우선순위:
    1. 환경변수 DATABASE_URL (Render에 설정된 Supabase URL)
    2. 로컬 SQLite 폴백 (개발 환경)
    """
    raw_url = os.environ.get("DATABASE_URL", "")

    if raw_url:
        # Supabase/PostgreSQL URL을 asyncpg 드라이버로 변환
        # postgresql://... → postgresql+asyncpg://...
        if raw_url.startswith("postgres://"):
            raw_url = raw_url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif raw_url.startswith("postgresql://") and "+asyncpg" not in raw_url:
            raw_url = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        logger.info(f"✅ PostgreSQL 사용: {raw_url[:50]}...")
        return raw_url

    # 로컬 SQLite 폴백
    local_path = Path(__file__).parent.parent / "data" / "songwork.db"
    local_path.parent.mkdir(parents=True, exist_ok=True)
    logger.info(f"ℹ️ SQLite 폴백: {local_path}")
    return f"sqlite+aiosqlite:///{local_path}"


DATABASE_URL = _build_database_url()

# 연결 설정 (PostgreSQL vs SQLite)
if "postgresql" in DATABASE_URL:
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        pool_size=5,
        max_overflow=10,
        pool_timeout=30,
        pool_recycle=1800,
        pool_pre_ping=True,
    )
else:
    # SQLite는 connection pool 설정 불필요
    engine = create_async_engine(DATABASE_URL, echo=False)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """테이블 생성 (없으면 자동 생성, 있으면 스킵)"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ DB 테이블 초기화 완료")
