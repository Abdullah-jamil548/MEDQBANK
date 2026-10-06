"""In-memory WebSocket fan-out for chat and friend events."""

from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from typing import Any
from uuid import UUID

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def is_online(self, user_id: UUID | str) -> bool:
        return bool(self._rooms.get(str(user_id)))

    async def connect(self, user_id: UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        key = str(user_id)
        async with self._lock:
            self._rooms[key].add(websocket)

    async def disconnect(self, user_id: UUID, websocket: WebSocket) -> None:
        key = str(user_id)
        async with self._lock:
            sockets = self._rooms.get(key)
            if not sockets:
                return
            sockets.discard(websocket)
            if not sockets:
                self._rooms.pop(key, None)

    async def send_to_user(self, user_id: UUID | str, payload: dict[str, Any]) -> bool:
        """Send payload; returns True if at least one socket accepted it."""
        key = str(user_id)
        async with self._lock:
            sockets = list(self._rooms.get(key, set()))
        if not sockets:
            return False
        data = json.dumps(payload, default=str)
        dead: list[WebSocket] = []
        delivered = False
        for ws in sockets:
            try:
                await ws.send_text(data)
                delivered = True
            except Exception:
                dead.append(ws)
        if dead:
            async with self._lock:
                living = self._rooms.get(key)
                if living is not None:
                    for ws in dead:
                        living.discard(ws)
                    if not living:
                        self._rooms.pop(key, None)
        return delivered

    def schedule_send(self, user_id: UUID | str, payload: dict[str, Any]) -> None:
        coro = self.send_to_user(user_id, payload)
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(coro)
            return
        except RuntimeError:
            pass
        loop = self._loop
        if loop is not None and loop.is_running():
            asyncio.run_coroutine_threadsafe(coro, loop)
            return
        coro.close()


manager = ConnectionManager()
