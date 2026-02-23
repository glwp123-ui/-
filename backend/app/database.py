"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- Supabase Transaction Pooler: statement_cache_size=0 필수
"""
import os
import logging
import asyncpg
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)


def _get_dsn() -> str:
    raw_url = os.environ.get("DATABASE_URL", "").strip()
    if not raw_url:
        raw_url = (
            "postgresql://"
            "postgres.prmebctnnphastindsjk:Songwork2025!@"
            "aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres"
        )
        logger.info("✅ PostgreSQL - Supabase 하드코딩 URL 사용")
    else:
        # postgres:// 또는 postgresql+asyncpg:// → postgresql://
        raw_url = raw_url.replace("postgresql+asyncpg://", "postgresql://")
        raw_url = raw_url.replace("postgres://", "postgresql://", 1)
        logger.info("✅ PostgreSQL - 환경변수 DATABASE_URL 사용")
    return raw_url


DSN = _get_dsn()
# SQLAlchemy용 URL (postgresql+asyncpg://)
DATABASE_URL = DSN.replace("postgresql://", "postgresql+asyncpg://", 1)


async def _asyncpg_connect(host, port, user, password, database, **kwargs):
    """statement_cache_size=0 강제 적용"""
    return await asyncpg.connect(
        host=host, port=port, user=user,
        password=password, database=database,
        statement_cache_size=0,
    )


engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=3,
    max_overflow=5,
    pool_timeout=30,
    pool_recycle=1800,
    pool_pre_ping=False,
    connect_args={"statement_cache_size": 0},
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
