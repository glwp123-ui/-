"""
song work - FastAPI 백엔드 서버
포트: 8000
DB : SQLite (data/songwork.db)

데이터 영속성:
- 시작 시 backup.json이 있으면 자동 복원 (Render 재배포 대응)
- 데이터 변경 시 자동 백업 (/data/backup.json 또는 로컬)
"""
import asyncio
import logging
from datetime import datetime, timedelta
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db, AsyncSessionLocal
from app.seed     import seed_if_empty
from app.backup_manager import save_backup, restore_from_backup
from app.routers  import auth, users, departments, tasks
from app.routers.backup import router as backup_router
from app.routers.daily_records import router as daily_records_router, _upsert_record

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ── 자정 자동 저장 스케줄러 ───────────────────────────
async def _auto_save_scheduler():
    """매일 자정(00:00 UTC)에 전날 보관함 자동 저장 + 백업"""
    while True:
        now = datetime.utcnow()
        next_midnight = (now + timedelta(days=1)).replace(
            hour=0, minute=0, second=5, microsecond=0
        )
        wait_secs = (next_midnight - now).total_seconds()
        await asyncio.sleep(wait_secs)

        yesterday = (datetime.utcnow() - timedelta(days=1)).date()
        try:
            async with AsyncSessionLocal() as db:
                await _upsert_record(yesterday, "auto", db)
        except Exception as e:
            logger.error(f"[auto-save] 오류: {e}")

        # 자정마다 백업도 저장
        try:
            async with AsyncSessionLocal() as db:
                await save_backup(db)
                logger.info("[auto-backup] 자정 자동 백업 완료")
        except Exception as e:
            logger.error(f"[auto-backup] 오류: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. 테이블 생성
    await init_db()

    async with AsyncSessionLocal() as db:
        # 2. 시드 데이터 (DB가 완전히 비어있을 때만)
        await seed_if_empty(db)

    # 3. 백업 파일이 있으면 복원 (시드 데이터 덮어쓰기)
    #    → Render 재배포 후에도 기존 데이터 유지
    async with AsyncSessionLocal() as db:
        restored = await restore_from_backup(db)
        if restored:
            logger.info("✅ 백업에서 데이터 복원 완료")
        else:
            logger.info("ℹ️ 백업 없음 - 시드 데이터로 시작")

    # 4. 스케줄러 시작
    task = asyncio.create_task(_auto_save_scheduler())

    yield

    # 종료 시 백업 저장
    try:
        async with AsyncSessionLocal() as db:
            await save_backup(db)
            logger.info("✅ 종료 전 백업 저장 완료")
    except Exception as e:
        logger.error(f"종료 백업 오류: {e}")

    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(
    title="song work API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS: Flutter Web → API 통신 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(departments.router)
app.include_router(tasks.router)
app.include_router(daily_records_router)
app.include_router(backup_router)


@app.get("/health")
async def health():
    from app.backup_manager import BACKUP_PATH
    backup_exists = BACKUP_PATH.exists()
    backup_size = BACKUP_PATH.stat().st_size if backup_exists else 0
    return {
        "status": "ok",
        "service": "song work API",
        "backup_file": str(BACKUP_PATH),
        "backup_exists": backup_exists,
        "backup_size_bytes": backup_size,
    }
