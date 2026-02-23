"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- Supabase Transaction Pooler 사용 (statement_cache_size=0 필수)
"""
import os
import logging
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)


def _build_database_url() -> str:
    raw_url = os.environ.get("DATABASE_URL", "").strip()

    if not raw_url:
        raw_url = (
            "postgresql+asyncpg://"
            "postgres.prmebctnnphastindsjk:Songwork2025!@"
            "aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres"
        )
        logger.info("✅ PostgreSQL - Supabase 하드코딩 URL 사용")
    else:
        if raw_url.startswith("postgres://"):
            raw_url = raw_url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif raw_url.startswith("postgresql://") and "+asyncpg" not in raw_url:
            raw_url = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        logger.info("✅ PostgreSQL - 환경변수 DATABASE_URL 사용")

    return raw_url


DATABASE_URL = _build_database_url()


def _make_engine():
    """asyncpg Transaction Pooler 전용 엔진 생성"""
    import asyncpg

    async def _creator():
        return await asyncpg.connect(
            dsn=DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://"),
            statement_cache_size=0,
        )

    # creator 방식 대신 connect_args 방식 사용
    return create_async_engine(
        DATABASE_URL,
        echo=False,
        pool_size=3,
        max_overflow=5,
        pool_timeout=30,
        pool_recycle=1800,
        pool_pre_ping=False,  # pre_ping도 prepared statement 사용하므로 비활성화
        connect_args={
            "statement_cache_size": 0,
            "prepared_statement_cache_size": 0,
        },
    )


engine = _make_engine()

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
