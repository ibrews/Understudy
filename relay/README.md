# Understudy Relay

A ~80-line Python WebSocket relay that lets Apple (iOS/visionOS) and Android devices join the same rehearsal room.

MultipeerConnectivity doesn't talk to Android, so we need a neutral transport. The relay is intentionally dumb — it just rebroadcasts every JSON frame to every other client in the same room. All schema/version logic lives in the clients.

## Run

```bash
pip install -r requirements.txt
python3 server.py
# Understudy relay starting on ws://0.0.0.0:8765
```

## Connect

```
ws://<relay-host>:8765/?room=<code>&id=<performer-id>&name=<label>
```

On Apple: Director panel → set **Transport: WebSocket** and point it at the relay.
On Android: Launch screen → enter relay URL.

Both sides send and receive the same `Envelope` JSON defined in `Networking/Transport.swift` (Swift) and `net/Envelope.kt` (Kotlin).

## Deployment

For a LAN rehearsal, run on any laptop and give its IP to the other devices. For remote rehearsals, drop it on a small VPS — it's one file and one pip dep.
