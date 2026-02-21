"""
song work - FastAPI 백엔드 서버
포트: 8000
DB : SQLite (data/songwork.db)
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import init_db, AsyncSessionLocal
from app.seed     import seed_if_empty
from app.routers  import auth, users, departments, tasks


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 앱 시작 시: 테이블 생성 → 시드 실행
    await init_db()
    async with AsyncSessionLocal() as db:
        await seed_if_empty(db)
    yield


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


@app.get("/health")
async def health():
    return {"status": "ok", "service": "song work API"}
