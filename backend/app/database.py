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
    raw_url = os.environ.get("DATABASE_URL", "").strip()

    if raw_url:
        # postgres:// → postgresql+asyncpg://
        if raw_url.startswith("postgres://"):
            raw_url = raw_url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif raw_url.startswith("postgresql://") and "+asyncpg" not in raw_url:
            raw_url = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        logger.info(f"✅ PostgreSQL(Supabase) 사용")
        return raw_url

    # 로컬 SQLite 폴백
    local_path = Path(__file__).parent.parent / "data" / "songwork.db"
    local_path.parent.mkdir(parents=True, exist_ok=True)
    logger.info(f"ℹ️ SQLite 폴백 사용: {local_path}")
    return f"sqlite+aiosqlite:///{local_path}"


# 매 요청마다 환경변수를 다시 읽지 않고 시작 시 한 번만 결정
DATABASE_URL = _build_database_url()

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
    engine = create_async_engine(DATABASE_URL, echo=False)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ DB 테이블 초기화 완료")
