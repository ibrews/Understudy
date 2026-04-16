# Understudy Wire Protocol v1

All cross-platform communication uses the same JSON schema over either
MultipeerConnectivity (Apple-only) or a WebSocket relay (mixed). Android speaks
only WebSocket. Apple can speak either.

## Connection

WebSocket URL:
```
ws://<relay-host>:<port>/?room=<code>&id=<performer-uuid>&name=<display-name>
```

On connect the relay sends a one-shot welcome frame (clients may ignore it):
```json
{"_relay": "welcome", "room": "rehearsal", "peers": 2}
```

## Envelope

Every logical message is wrapped in an envelope:

```json
{
  "version": 1,
  "senderID": {"raw": "9F3E-..."},
  "message": <NetMessage>
}
```

Clients MUST drop envelopes whose `version` ≠ 1.

## NetMessage

Swift `enum NetMessage` encodes with `Codable`'s default enum strategy:

```json
{"<caseName>": { <associated-values-as-object> }}
```

For an enum case with **unlabeled** associated values, the inner object keys are `_0`, `_1`, `_2` … (positional). For cases with **labeled** associated values, the inner object keys are the label names. Optional values encoded as `nil` are **omitted** from the object entirely (not `null`).

Known cases (authoritative list — see `Networking/Transport.swift`):

| Case                | Shape (verified empirically from Swift 5.10 `JSONEncoder`)                                       |
|---------------------|--------------------------------------------------------------------------------------------------|
| `hello`             | `{"hello": {"_0": <Performer>}}`                                                                 |
| `goodbye`           | `{"goodbye": {"_0": <ID>}}`                                                                      |
| `performerUpdate`   | `{"performerUpdate": {"_0": <Performer>}}`                                                       |
| `blockingSnapshot`  | `{"blockingSnapshot": {"_0": <Blocking>}}`                                                       |
| `markAdded`         | `{"markAdded": {"_0": <Mark>}}`                                                                  |
| `markUpdated`       | `{"markUpdated": {"_0": <Mark>}}`                                                                |
| `markRemoved`       | `{"markRemoved": {"_0": <ID>}}`                                                                  |
| `cueFired`          | `{"cueFired": {"markID": <ID>, "cueID": <ID>, "by": <ID>}}`                                      |
| `playbackState`     | `{"playbackState": {"t": <Double>}}` (key absent when `t` is nil)                                |

## Value types

### ID
```json
{"raw": "9F3E-4BAE-..."}
```

### Pose
```json
{"x": 1.2, "y": 0.0, "z": -0.5, "yaw": 0.0}
```
Units: meters, radians. `yaw` is rotation about +Y (world up).

### Performer
```json
{
  "id": <ID>,
  "displayName": "Alex's Pixel 8",
  "role": "performer",           // "director" | "performer" | "observer"
  "pose": <Pose>,
  "trackingQuality": 1.0,        // 0 … 1
  "currentMarkID": <ID or null>
}
```

### Cue (enum — all cases have labeled associated values)
```json
{"line":  {"id": <ID>, "text": "Something is rotten", "character": "MARCELLUS"}}
{"sfx":   {"id": <ID>, "name": "thunder"}}
{"light": {"id": <ID>, "color": "amber", "intensity": 0.8}}   // color in { warm, cool, red, blue, green, amber, blackout }
{"note":  {"id": <ID>, "text": "beat here"}}
{"wait":  {"id": <ID>, "seconds": 1.5}}
```
A nil `character` in `line` is encoded by **omitting** the `character` key.

### Mark
```json
{
  "id": <ID>,
  "name": "Mark 3",
  "pose": <Pose>,
  "radius": 0.6,
  "cues": [<Cue>, ...],
  "sequenceIndex": 2
}
```

### Blocking
```json
{
  "id": <ID>,
  "title": "Untitled Piece",
  "authorName": "",
  "createdAt": "<ISO-8601>",
  "modifiedAt": "<ISO-8601>",
  "marks": [<Mark>, ...],
  "origin": <Pose>,
  "reference": null | {
    "performerName": "Alex",
    "samples": [{"t": 0.0, "pose": <Pose>}, ...],
    "duration": 12.34
  }
}
```

## Quirks to match

- Swift's default `Codable` encodes enum cases with associated values as a single-key object whose **value is an array** for positional associated values, or a **keyed object** for labeled associated values. `cueFired` uses labels so it's an object; everything else uses positional arrays.
- Android's Kotlin Serialization must be configured to match this: use `@Serializable sealed class` with a custom discriminator or hand-rolled polymorphic adapter — see `android/app/src/main/java/agilelens/understudy/net/Envelope.kt`.
- Dates are encoded as **ISO-8601 strings** (`2026-04-16T15:23:01Z`) via `WireCoding.encoder`. Android uses `kotlinx-datetime` or `Instant.parse(...)`.

## Reliability / throttling

- Pose updates should be throttled to 10 Hz on the sender.
- All messages are best-effort — the relay/MPC does not retry.
- Clients MUST NOT crash on unknown top-level keys — older peers may lack features.
