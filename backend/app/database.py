"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- 환경변수 DATABASE_URL 우선 사용
- 없으면 하드코딩 fallback
"""
import os
import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)

# ── DB URL 결정 ───────────────────────────────────────────
def _build_database_url() -> str:
    raw_url = os.environ.get("DATABASE_URL", "").strip()

    if not raw_url:
        # 환경변수 없으면 하드코딩 fallback (Supabase Transaction Pooler)
        raw_url = (
            "postgresql+asyncpg://"
            "postgres.prmebctnnphastindsjk:Songwork2025!@"
            "aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres"
        )
        logger.info("✅ PostgreSQL - Supabase 하드코딩 URL 사용")
        return raw_url

    # postgres:// → postgresql+asyncpg:// 변환
    if raw_url.startswith("postgres://"):
        raw_url = raw_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif raw_url.startswith("postgresql://") and "+asyncpg" not in raw_url:
        raw_url = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)

    logger.info("✅ PostgreSQL - 환경변수 DATABASE_URL 사용")
    return raw_url


DATABASE_URL = _build_database_url()

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=1800,
    pool_pre_ping=True,
)

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
