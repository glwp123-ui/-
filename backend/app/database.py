"""
SQLite + SQLAlchemy 비동기 DB 설정
- 로컬 개발: /home/user/backend/data/songwork.db
- Render 배포: /data/songwork.db  (Persistent Disk 마운트 경로)
- 환경변수 DB_PATH 로 직접 지정 가능
"""
import os
from pathlib import Path
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

# DB 경로 우선순위: 환경변수 > Render 디스크(/data) > 로컬 기본값
def _resolve_db_path() -> str:
    if os.environ.get("DB_PATH"):
        return os.environ["DB_PATH"]
    # Render Persistent Disk 마운트 경로
    render_path = Path("/data/songwork.db")
    if render_path.parent.exists():
        return str(render_path)
    # 로컬 기본값
    local_path = Path(__file__).parent.parent / "data" / "songwork.db"
    local_path.parent.mkdir(parents=True, exist_ok=True)
    return str(local_path)

_DB_FILE    = _resolve_db_path()
DATABASE_URL = f"sqlite+aiosqlite:///{_DB_FILE}"

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
