"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- Supabase Transaction Pooler: asyncpg creator 방식으로 statement_cache_size=0 강제 적용
"""
import os
import logging
import asyncpg
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)


def _get_conn_params() -> dict:
    raw_url = os.environ.get("DATABASE_URL", "").strip()

    if not raw_url:
        raw_url = (
            "postgresql://"
            "postgres.prmebctnnphastindsjk:Songwork2025!@"
            "aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres"
        )
        logger.info("✅ PostgreSQL - Supabase 하드코딩 URL 사용")
    else:
        raw_url = raw_url.replace("postgresql+asyncpg://", "postgresql://")
        raw_url = raw_url.replace("postgres://", "postgresql://", 1)
        logger.info("✅ PostgreSQL - 환경변수 DATABASE_URL 사용")

    # postgresql://user:pass@host:port/db 파싱
    from urllib.parse import urlparse
    p = urlparse(raw_url)
    return {
        "host": p.hostname,
        "port": p.port or 5432,
        "user": p.username,
        "password": p.password,
        "database": p.path.lstrip("/"),
    }


_PARAMS = _get_conn_params()

# SQLAlchemy용 dummy URL (실제 연결은 creator 함수가 처리)
_DUMMY_URL = (
    f"postgresql+asyncpg://{_PARAMS['user']}:{_PARAMS['password']}"
    f"@{_PARAMS['host']}:{_PARAMS['port']}/{_PARAMS['database']}"
)
DATABASE_URL = _DUMMY_URL


async def _creator():
    """statement_cache_size=0 강제 적용한 asyncpg 연결 생성"""
    return await asyncpg.connect(
        host=_PARAMS["host"],
        port=_PARAMS["port"],
        user=_PARAMS["user"],
        password=_PARAMS["password"],
        database=_PARAMS["database"],
        statement_cache_size=0,
    )


engine = create_async_engine(
    "postgresql+asyncpg://",
    async_creator=_creator,
    echo=False,
    pool_size=3,
    max_overflow=5,
    pool_timeout=30,
    pool_recycle=1800,
    pool_pre_ping=False,
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
