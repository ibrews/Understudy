# Understudy

**Multiplayer spatial theater. One director on Vision Pro, any number of performers on iPhone.**

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
┌──────────────────────────┐                 ┌──────────────────────────┐
│ Vision Pro — DIRECTOR    │                 │ iPhone  — PERFORMER      │
│                          │   MPC / LAN     │                          │
│  • tap to place marks    │ ◄──────────────►│  • teleprompter          │
│  • edit lines / cues     │   JSON msgs     │  • GPS ring to next mark │
│  • see ghost performers  │                 │  • haptic on entry       │
│  • ribbon = sequence     │                 │  • record walk           │
└──────────────────────────┘                 └──────────────────────────┘
```

### Roles
| Platform       | Role      | Primary verbs                                    |
|----------------|-----------|--------------------------------------------------|
| visionOS       | Director  | place marks, author cues, watch the whole stage  |
| iOS            | Performer | be tracked in AR, receive cues, record a walk    |
| iOS (future)   | Observer  | watch the stage without affecting it             |
| Android (TBD)  | Performer | same phone role via WebSocket bridge             |

### Architecture

- **Single Swift target**, `#if os(iOS)` / `#if os(visionOS)` switches the view.
- **Models** are pure value types (`Pose`, `Mark`, `Cue`, `Blocking`) — trivially `Codable` and `Sendable`, marked `nonisolated` to cross actor boundaries.
- **`BlockingStore`** is a MainActor-isolated `@Observable` owned by both views.
- **`Transport`** protocol isolates the wire — today MultipeerConnectivity (iOS↔iOS, iOS↔visionOS), tomorrow a `WebSocketTransport` for Android.
- **ARKit** feeds `updateLocalPose` ~30× / sec on iOS; visionOS uses RealityKit anchors for the stage.
- **Cue firing** happens on mark *entry* (transition edge), not per-frame inside the radius — so cues don't re-fire if you wiggle.

## Run it

Requires Xcode 15.4+, an iPhone, and (optionally) an Apple Vision Pro on the same Wi-Fi.

```bash
open Understudy.xcodeproj
# choose "Understudy" scheme, pick an iOS simulator or device → Run
# separately, pick a visionOS simulator → Run
```

Both devices auto-discover each other over Bonjour (`_und-stage._tcp`). Change the **Room** field on the director panel to create isolated sessions.

## Roadmap

- [x] iOS performer (ARKit + haptics + teleprompter)
- [x] visionOS director (RealityKit + tap-to-place + ribbon)
- [x] Multipeer sync of marks and performer positions
- [x] Cue editor (lines, notes)
- [x] Walk recording (stored on Blocking as `reference`)
- [ ] Playback ghost — replay recorded walk as AR avatar
- [ ] SFX and Light cues actually *do* something (wire up AudioPlayer, RealityKit light)
- [ ] Save / load blockings to disk (JSON already, just needs a browser)
- [ ] Android performer via WebSocket bridge (CameraX + ARCore → same pose shape)
- [ ] Collaborative AR origin anchor (so all devices agree on (0,0) in the room)
- [ ] TestFlight

## Project rules

- Version is shown in both the director panel and the performer HUD (`AppVersion.formatted`) and must match `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.pbxproj`.
- Every build push bumps the version. No exceptions.

## License

Personal project. All rights reserved for now — ping if you want to build on it.

## Credits

Designed and built by [Alex Coulombe](https://alexcoulombe.com) and Claude, in one ambitious afternoon.
