from contextlib import asynccontextmanager

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.auth import decode_access_token
from app.config import get_settings
from app.db import SessionLocal, init_schemas_and_tables
from app.models import User
from app.realtime import manager as ws_manager
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
        "friends/chat with WebSocket realtime, and annotation sync."
    ),
    version="0.3.0",
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


@app.websocket("/api/v1/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
):
    """Realtime channel for chat messages and friend requests."""
    try:
        user_id = decode_access_token(token, settings)
    except Exception:
        await websocket.close(code=4401)
        return

    if SessionLocal is None:
        await websocket.close(code=1013)
        return

    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.user_id == user_id, User.is_active.is_(True)))
        if user is None:
            await websocket.close(code=4401)
            return
    finally:
        db.close()

    await ws_manager.connect(user_id, websocket)
    try:
        await websocket.send_json({"type": "connected", "user_id": str(user_id)})
        while True:
            # Keep-alive / ignore client pings
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await ws_manager.disconnect(user_id, websocket)


@app.get("/")
def root():
    return {
        "app": settings.app_name,
        "docs": "/docs",
        "health": "/api/v1/health",
        "auth": ["/api/v1/auth/register", "/api/v1/auth/login"],
        "books": "/api/v1/books",
        "ws": "/api/v1/ws?token=<jwt>",
        "sync": "/api/v1/sync",
        "hint": "Register, sync books from R2, then use Bearer token for access + annotations",
    }
