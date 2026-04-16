# Understudy

**Multiplayer spatial theater. One director on Vision Pro, any number of performers on iPhone or Android.**

Understudy turns a real room into a programmable stage. The director — wearing Apple Vision Pro — places blocking marks, lines, cues, and lights in 3D space. Each performer holds an iPhone that acts as a teleprompter, a GPS-for-theater, and a haptic cueing device. Walk onto a mark: your phone pulses, shows your next line, and the director sees you arrive.

The killer feature: record a blocking once, and **anyone with a phone can play it back** — the phone guides them through the marks like turn-by-turn directions, delivering the cues at the right moment. Site-specific theater becomes shareable. Rehearsal becomes async. An audience member can literally walk the actor's path after the show ends.

> "Figma for stage direction." — *you, hopefully, in about twenty seconds*

![Understudy](Understudy/Assets.xcassets/AppIcon.appiconset/Icon-1024.png)

---

## Why this

- **Architects** do sightline studies and walk-throughs; they'd use this for live venue design.
- **Theater-makers** block rehearsals in empty rooms before they ever see the real stage.
- **Immersive-experience designers** prototype interactive paths without building a CMS.
- **XR pre-viz** teams use it to scout spatial choreography with real bodies before MoCap.

Nobody ships this. That's the opportunity.

## How it works

```
┌──────────────────────────┐      MPC / LAN       ┌──────────────────────────┐
│ Vision Pro — DIRECTOR    │◄────────────────────►│ iPhone  — PERFORMER      │
│                          │    (auto-Bonjour)    │                          │
│  • tap to place marks    │                      │  • teleprompter          │
│  • edit lines / cues     │                      │  • live AR stage view    │
│  • see ghost performers  │◄────┐                │  • GPS ring to next mark │
│  • scrub recorded walks  │     │  WebSocket     │  • haptic + flash cues   │
│  • SFX / light cues fire │     │  relay (JSON)  │  • record + playback     │
└──────────────────────────┘     │                └──────────────────────────┘
                                 │                             │
                                 ▼                             ▼
                          ┌──────────────┐        ┌──────────────────────────┐
                          │  relay/      │◄──────►│ Android — PERFORMER      │
                          │  (Python)    │        │ (ARCore + OkHttp WS)     │
                          └──────────────┘        └──────────────────────────┘
```

### Roles
| Platform       | Role      | Primary verbs                                    |
|----------------|-----------|--------------------------------------------------|
| visionOS       | Director  | place marks, author cues, watch the whole stage  |
| iOS            | Performer | be tracked in AR, receive cues, record a walk    |
| iOS (future)   | Observer  | watch the stage without affecting it             |
| Android (TBD)  | Performer | same phone role via WebSocket bridge             |

### Architecture

- **Single Swift target** for iOS + visionOS; `#if os(iOS)` / `#if os(visionOS)` switches the view.
- **Models** are pure value types (`Pose`, `Mark`, `Cue`, `Blocking`) — `Codable` and `Sendable`, marked `nonisolated` to cross actor boundaries.
- **`BlockingStore`** is a MainActor-isolated `@Observable` owned by both views. Mark entry enqueues `FiredCue`s; `CueFXEngine` drains the queue and plays sounds / flashes colors / tints the visionOS stage.
- **`Transport`** protocol isolates the wire. `MultipeerTransport` speaks Bonjour over LAN (Apple-only). `WebSocketTransport` speaks to the Python relay for Android interop. Either can be picked at runtime from the Transport menu.
- **`WireCoding`** is the shared JSONEncoder/Decoder (ISO-8601 dates) used by both transports — cross-platform safe.
- **ARKit** on iOS feeds camera transforms into `updateLocalPose` ~30Hz; visionOS uses RealityKit world anchors for the stage. Cue firing is on mark *entry* (transition edge) so cues don't re-fire when you wiggle.
- **Android** uses ARCore for pose + OkHttp WebSocket + kotlinx-serialization with a custom polymorphic adapter that mirrors Swift's default Codable enum encoding.

## Run it

See **[QUICKSTART.md](QUICKSTART.md)** for the full multi-device flow. TL;DR:

- **Pure Apple rehearsal** — open `Understudy.xcodeproj`, run to visionOS + iOS; MultipeerConnectivity auto-discovers over Bonjour (`_und-stage._tcp`).
- **Cross-platform rehearsal with Android** — `cd relay && python3 server.py`, then in each app set Transport → WebSocket and point at the relay's LAN IP.

## Repo layout

| Folder            | What's in it                                                            |
|-------------------|-------------------------------------------------------------------------|
| `Understudy/`     | Swift source — iOS + visionOS from one target                           |
| `android/`        | Android Studio project — Kotlin, Jetpack Compose, ARCore, OkHttp       |
| `relay/`          | Python WebSocket relay (~100 lines, one pip dep)                        |
| `test-fixtures/`  | Swift-generated JSON fixtures so Kotlin tests can round-trip the wire   |
| `PROTOCOL.md`     | Authoritative wire format documentation                                 |
| `QUICKSTART.md`   | How to get the whole stack running                                       |

## Roadmap

### v0.1
- [x] iOS performer (ARKit + haptics + teleprompter)
- [x] visionOS director (RealityKit + tap-to-place + ribbon)
- [x] Multipeer sync of marks and performer positions
- [x] Cue editor (lines, notes)
- [x] Walk recording (stored on Blocking as `reference`)

### v0.2
- [x] iPhone AR stage view — live camera with floor-anchored marks
- [x] Playback ghost — replay recorded walk as AR avatar on both phones and AVP
- [x] SFX cues play system sounds (bell/thunder/chime/knock/applause)
- [x] Light cues flash the phone + tint the immersive stage
- [x] **Android performer** — ARCore world tracking + OkHttp WebSocket
- [x] **WebSocket relay** — Python server, room-scoped broadcast, cross-platform

### Next
- [ ] Save / load blockings to disk (JSON already, just needs a browser)
- [ ] Collaborative AR origin anchor (so all devices agree on (0,0) in the room)
- [ ] iPhone author mode (drop marks from phone without AVP)
- [ ] DMX / QLab bridge for real theater rigs
- [ ] TestFlight

## Project rules

- Version is shown in both the director panel and the performer HUD (`AppVersion.formatted`) and must match `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.pbxproj`.
- Every build push bumps the version. No exceptions.

## License

Personal project. All rights reserved for now — ping if you want to build on it.

## Credits

Designed and built by [Alex Coulombe](https://alexcoulombe.com) and Claude, in one ambitious afternoon.
