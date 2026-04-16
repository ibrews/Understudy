#!/usr/bin/env python3
"""
Understudy WebSocket relay.

A minimal room-scoped message bus so Apple (iOS/visionOS) and Android devices
can exchange the same Envelope/NetMessage JSON used by MultipeerConnectivity.

Each client connects to  ws://<host>:8765/?room=<code>&id=<perf-id>&name=<label>
and every JSON frame it sends is rebroadcast to every OTHER client in the same
room, verbatim. The server is intentionally dumb: no schema, no versioning,
no persistence. That's the iOS side's job.

Run:
    python3 server.py                       # binds 0.0.0.0:8765
    python3 server.py --host 127.0.0.1      # localhost only
    python3 server.py --port 9000
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, Set
from urllib.parse import parse_qs, urlparse

try:
    import websockets
except ImportError:
    print("pip install websockets  # required", flush=True)
    raise

log = logging.getLogger("understudy.relay")


@dataclass(eq=False)  # identity-based hashing so we can store Clients in a set
class Client:
    ws: "websockets.ServerConnection"
    room: str
    perf_id: str
    name: str


@dataclass
class Room:
    clients: Set[Client] = field(default_factory=set)


class Hub:
    def __init__(self) -> None:
        self.rooms: Dict[str, Room] = defaultdict(Room)
        self._lock = asyncio.Lock()

    async def join(self, client: Client) -> None:
        async with self._lock:
            self.rooms[client.room].clients.add(client)
        log.info("join  room=%s name=%s (%d in room)",
                 client.room, client.name, len(self.rooms[client.room].clients))

    async def leave(self, client: Client) -> None:
        async with self._lock:
            self.rooms[client.room].clients.discard(client)
            count = len(self.rooms[client.room].clients)
            if count == 0:
                self.rooms.pop(client.room, None)
        log.info("leave room=%s name=%s (%d in room)",
                 client.room, client.name, count)

    async def broadcast(self, sender: Client, payload: str) -> None:
        room = self.rooms.get(sender.room)
        if room is None:
            return
        # Snapshot the set so mutation during iteration is safe.
        for peer in list(room.clients):
            if peer is sender:
                continue
            try:
                await peer.ws.send(payload)
            except Exception as exc:  # noqa: BLE001
                log.warning("drop peer=%s: %s", peer.name, exc)

    def room_count(self, room: str) -> int:
        return len(self.rooms.get(room, Room()).clients)


async def handler(ws: "websockets.ServerConnection", hub: Hub) -> None:
    # Parse query string — websockets exposes the path on the connection.
    query = parse_qs(urlparse(ws.request.path).query)
    room = (query.get("room") or ["default"])[0]
    perf_id = (query.get("id") or [""])[0] or f"anon-{id(ws)}"
    name = (query.get("name") or ["anon"])[0]

    client = Client(ws=ws, room=room, perf_id=perf_id, name=name)
    await hub.join(client)
    # Send a tiny welcome frame that Android/iOS can ignore or use for peer-count display.
    try:
        await ws.send(json.dumps({
            "_relay": "welcome",
            "room": room,
            "peers": hub.room_count(room),
        }))
    except Exception:
        pass

    try:
        async for message in ws:
            if not isinstance(message, (str, bytes)):
                continue
            payload = message.decode() if isinstance(message, bytes) else message
            await hub.broadcast(client, payload)
    except websockets.ConnectionClosed:
        pass
    finally:
        await hub.leave(client)


async def main() -> None:
    parser = argparse.ArgumentParser(description="Understudy WebSocket relay")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    hub = Hub()

    async def serve(ws):
        await handler(ws, hub)

    log.info("Understudy relay starting on ws://%s:%d", args.host, args.port)
    async with websockets.serve(serve, args.host, args.port, max_size=2**20):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
