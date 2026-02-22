"""
song work - FastAPI 백엔드 서버
포트: 8000
DB : SQLite (data/songwork.db)
"""
import asyncio
from datetime import datetime, timedelta
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db, AsyncSessionLocal
from app.seed     import seed_if_empty
from app.routers  import auth, users, departments, tasks
from app.routers.daily_records import router as daily_records_router, _upsert_record


# ── 자정 자동 저장 스케줄러 ───────────────────────────
async def _auto_save_scheduler():
    """매일 자정(00:00 UTC)에 전날 보관함 자동 저장"""
    while True:
        now = datetime.utcnow()
        # 다음 자정까지 대기
        next_midnight = (now + timedelta(days=1)).replace(
            hour=0, minute=0, second=5, microsecond=0
        )
        wait_secs = (next_midnight - now).total_seconds()
        await asyncio.sleep(wait_secs)

        # 자정이 됐을 때 → 전날(어제) 기록 저장
        yesterday = (datetime.utcnow() - timedelta(days=1)).date()
        try:
            async with AsyncSessionLocal() as db:
                await _upsert_record(yesterday, "auto", db)
        except Exception as e:
            print(f"[auto-save] 오류: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 앱 시작 시: 테이블 생성 → 시드 실행 → 스케줄러 시작
    await init_db()
    async with AsyncSessionLocal() as db:
        await seed_if_empty(db)

    # 자정 자동 저장 백그라운드 태스크 시작
    task = asyncio.create_task(_auto_save_scheduler())

    yield

    # 앱 종료 시 정리
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


@app.get("/health")
async def health():
    return {"status": "ok", "service": "song work API"}
