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

    async def send_to_user(self, user_id: UUID | str, payload: dict[str, Any]) -> None:
        key = str(user_id)
        async with self._lock:
            sockets = list(self._rooms.get(key, set()))
        if not sockets:
            return
        data = json.dumps(payload, default=str)
        dead: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_text(data)
            except Exception:
                dead.append(ws)
        if dead:
            async with self._lock:
                living = self._rooms.get(key)
                if living is None:
                    return
                for ws in dead:
                    living.discard(ws)
                if not living:
                    self._rooms.pop(key, None)

    def schedule_send(self, user_id: UUID | str, payload: dict[str, Any]) -> None:
        """Fire-and-forget from sync route handlers."""
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        loop.create_task(self.send_to_user(user_id, payload))


manager = ConnectionManager()
