import asyncio
import json
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from app.admin import router as admin_router
from app.auth import decode_access_token
from app.config import get_settings
from app.db import SessionLocal, init_schemas_and_tables
from app.models import ChatMessage, User
from app.realtime import manager as ws_manager
from app.router import router

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    ws_manager.bind_loop(asyncio.get_running_loop())
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
app.include_router(admin_router, prefix="/api/v1")


async def _flush_undelivered(user_id: uuid.UUID) -> None:
    """When a user comes online, mark pending inbox messages delivered."""
    if SessionLocal is None:
        return
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        rows = list(
            db.scalars(
                select(ChatMessage).where(
                    ChatMessage.recipient_id == user_id,
                    ChatMessage.delivered_at.is_(None),
                )
            ).all()
        )
        if not rows:
            return
        by_sender: dict[uuid.UUID, list[str]] = {}
        for row in rows:
            row.delivered_at = now
            by_sender.setdefault(row.sender_id, []).append(str(row.message_id))
        db.commit()
        for sender_id, ids in by_sender.items():
            await ws_manager.send_to_user(
                sender_id,
                {
                    "type": "chat.delivered",
                    "message_ids": ids,
                    "delivered_at": now.isoformat(),
                    "by_user_id": str(user_id),
                    "show_notification": False,
                },
            )
    except Exception as exc:
        print(f"[ws] flush undelivered failed: {exc}")
    finally:
        db.close()


async def _ack_delivered(user_id: uuid.UUID, message_ids: list[str]) -> None:
    if SessionLocal is None or not message_ids:
        return
    parsed: list[uuid.UUID] = []
    for raw in message_ids:
        try:
            parsed.append(uuid.UUID(str(raw)))
        except Exception:
            continue
    if not parsed:
        return
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        rows = list(
            db.scalars(
                select(ChatMessage).where(
                    ChatMessage.recipient_id == user_id,
                    ChatMessage.message_id.in_(parsed),
                    ChatMessage.delivered_at.is_(None),
                )
            ).all()
        )
        if not rows:
            return
        by_sender: dict[uuid.UUID, list[str]] = {}
        for row in rows:
            row.delivered_at = now
            by_sender.setdefault(row.sender_id, []).append(str(row.message_id))
        db.commit()
        for sender_id, ids in by_sender.items():
            await ws_manager.send_to_user(
                sender_id,
                {
                    "type": "chat.delivered",
                    "message_ids": ids,
                    "delivered_at": now.isoformat(),
                    "by_user_id": str(user_id),
                    "show_notification": False,
                },
            )
    except Exception as exc:
        print(f"[ws] ack delivered failed: {exc}")
    finally:
        db.close()


@app.websocket("/api/v1/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
):
    """Realtime channel for chat messages, typing, and friend events."""
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
        await _flush_undelivered(user_id)
        while True:
            raw = await websocket.receive_text()
            if raw in ("", "ping", "pong"):
                continue
            try:
                data = json.loads(raw)
            except Exception:
                continue
            if not isinstance(data, dict):
                continue
            event_type = data.get("type")
            if event_type == "typing":
                to_user_id = data.get("to_user_id")
                if to_user_id:
                    await ws_manager.send_to_user(
                        to_user_id,
                        {
                            "type": "chat.typing",
                            "from_user_id": str(user_id),
                            "is_typing": bool(data.get("is_typing", True)),
                            "show_notification": False,
                        },
                    )
            elif event_type == "chat.ack":
                ids = data.get("message_ids") or []
                if isinstance(ids, list):
                    await _ack_delivered(user_id, [str(i) for i in ids])
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
        "auth": ["/api/v1/auth/login"],
        "books": "/api/v1/books",
        "ws": "/api/v1/ws?token=<jwt>",
        "sync": "/api/v1/sync",
        "admin": "/admin",
        "hint": "Login, sync books from R2, then use Bearer token for access + annotations",
    }


ADMIN_DIST = Path(__file__).resolve().parents[1] / "admin" / "dist"


if ADMIN_DIST.is_dir():
    assets_dir = ADMIN_DIST / "assets"
    if assets_dir.is_dir():
        app.mount("/admin/assets", StaticFiles(directory=assets_dir), name="admin-assets")

    @app.get("/admin")
    @app.get("/admin/{path:path}")
    def admin_spa(path: str = ""):
        candidate = ADMIN_DIST / path
        if path and candidate.is_file():
            return FileResponse(candidate)
        index = ADMIN_DIST / "index.html"
        if not index.is_file():
            return {"detail": "Admin UI is not built. Run npm run build in backend/admin."}
        return FileResponse(index)

