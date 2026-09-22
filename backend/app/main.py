from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db import init_schemas_and_tables
from app.router import router

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if settings.db_configured:
        try:
            init_schemas_and_tables()
        except Exception as exc:
            # App still starts; /health reports db_ok=false
            print(f"[startup] DB init failed: {exc}")
    yield


app = FastAPI(
    title=settings.app_name,
    description=(
        "MedQBank API: auth, PDF book catalog (Postgres), Cloudflare R2 delivery, "
        "and offline-friendly highlight/note/progress sync."
    ),
    version="0.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")


@app.get("/")
def root():
    return {
        "app": settings.app_name,
        "docs": "/docs",
        "health": "/api/v1/health",
        "auth": ["/api/v1/auth/register", "/api/v1/auth/login"],
        "books": "/api/v1/books",
        "sync": "/api/v1/sync",
        "hint": "Register, sync books from R2, then use Bearer token for access + annotations",
    }
