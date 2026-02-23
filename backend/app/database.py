"""
PostgreSQL (Supabase) + SQLAlchemy 비동기 DB 설정
- Supabase Session Pooler (포트 5432) 사용 - prepared statement 문제 없음
- Transaction Pooler (포트 6543)은 asyncpg와 호환 안 됨 → Session Pooler로 변경
"""
import os
import logging
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)


def _build_database_url() -> str:
    """
    DATABASE_URL 환경변수 우선 사용.
    없으면 Supabase Session Pooler URL (포트 5432) 사용.
    
    ⚠️ 중요: Transaction Pooler (포트 6543) → Session Pooler (포트 5432)로 변경
    Session Pooler는 prepared statement를 지원하므로 asyncpg와 호환됨.
    """
    raw_url = os.environ.get("DATABASE_URL", "").strip()

    if raw_url:
        logger.info("✅ PostgreSQL - 환경변수 DATABASE_URL 사용")
    else:
        # Session Pooler: 포트 5432 사용 (Transaction Pooler 6543 아님!)
        raw_url = (
            "postgresql://"
            "postgres.prmebctnnphastindsjk:Songwork2025!@"
            "aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres"
        )
        logger.info("✅ PostgreSQL - Supabase Session Pooler URL 사용 (포트 5432)")

    # scheme 변환: asyncpg 드라이버용
    if raw_url.startswith("postgres://"):
        raw_url = raw_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif raw_url.startswith("postgresql://"):
        raw_url = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    elif not raw_url.startswith("postgresql+asyncpg://"):
        raw_url = "postgresql+asyncpg://" + raw_url.split("://", 1)[-1]

    return raw_url


DATABASE_URL = _build_database_url()

# Session Pooler는 prepared statement 지원 → statement_cache_size=0 불필요
# 하지만 안전을 위해 connect_args에 설정
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=1800,
    pool_pre_ping=True,
    connect_args={
        "statement_cache_size": 0,  # 혹시 모를 Pooler 충돌 방지
        "server_settings": {
            "application_name": "songwork-api"
        }
    }
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
