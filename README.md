# Understudy

**Multiplayer spatial theater. A Vision Pro director, iPhones and Android performers, and the actual script of Hamlet in your pocket.**

Understudy turns a real room into a programmable stage.

A **director** wearing Apple Vision Pro places blocking marks on the floor — actual points in 3D space — and attaches lines, sound cues, light cues, and beats to each one. **Performers** hold phones that become smart teleprompters: walk onto a mark, your phone pulses, the next line appears, the sound fires, the "amber" light washes the room. The director sees every performer as a ghost avatar moving through the same virtual stage, in real time.

Record a blocking once and anyone else with a phone can *walk it back* — the app becomes a self-paced AR audio tour of your own show. Site-specific theater becomes shareable. Rehearsal becomes async. The audience can literally step into the actor's path after the curtain falls.

And because the entire text of **Hamlet** is bundled in the app, you don't have to type a single line. Drop a mark at Francisco's post, open the Script Browser, tap Bernardo's "Who's there?" — it's on the mark. Tap the next line, the next.

![Understudy app icon](Understudy/Assets.xcassets/AppIcon.appiconset/Icon-1024.png)

> *"Figma for stage direction."*

---

## Who this is for

| You are… | Understudy gives you… |
|----|----|
| **A theater director or stage manager** | Block scenes without a venue. Save blockings as files, share them with your cast, rehearse remotely. Import your own script later. |
| **An architect designing a venue** | Walk sightlines and circulation paths with real bodies before construction. Every performer's position is a live datapoint. |
| **An XR pre-viz team** | Scout spatial choreography with phones you already have, before you commit to MoCap or a game engine. |
| **An immersive experience designer** | Prototype interactive paths and cue chains in a day. The audience mode ships a finished product. |
| **A curious person on a Sunday** | Tap your floor a few times and watch a five-mark Hamlet abridgement fire its cues as you walk. It takes ninety seconds. |

---

## The three apps + the relay

```
┌──────────────────────────┐      MPC / LAN       ┌──────────────────────────┐
│  Apple Vision Pro        │◄────────────────────►│  iPhone                  │
│  DIRECTOR                │    (auto-Bonjour)    │  PERFORM / AUTHOR /      │
│                          │                      │  AUDIENCE                │
│  • tap to place marks    │                      │                          │
│  • edit cues & scripts   │                      │  • live AR stage         │
│  • see performer ghosts  │◄────┐                │  • tap-floor to author   │
│  • scrub recorded walks  │     │  WebSocket     │  • Hamlet browser        │
│  • SFX / Light cues fire │     │  relay         │  • ghost playback        │
└──────────────────────────┘     │                └──────────────────────────┘
                                 │                             │
                                 ▼                             ▼
                          ┌──────────────┐        ┌──────────────────────────┐
                          │   relay/     │◄──────►│  Android phone           │
                          │  Python WS   │        │  PERFORMER               │
                          │  ~100 LOC    │        │  (ARCore + OkHttp WS)    │
                          └──────────────┘        └──────────────────────────┘
```

Apple devices on the same LAN find each other automatically over Bonjour and exchange state via **MultipeerConnectivity** — no setup, no server. When you want Android in the room, spin up the Python relay on any Mac/Linux box and switch every app's Transport to **WebSocket relay**. Same wire format, same rooms, same cues.

---

## Modes — what happens when you launch

On visionOS, you're always the **Director**. On iPhone/Android, a first-launch picker asks what you're here for:

### Perform
The default. Walk the blocking. A full-screen AR camera feed behind a dark curtain gradient shows you where the marks are as glowing discs on the floor; a guidance ring shrinks as you approach the next one. Haptic pulse on entry. The next line materialises in serif type over the camera feed.

### Author  *(iPhone)*
Tap the floor to drop a mark at the raycast point. Tap a mark to open an inline editor where you can add lines, sound cues, light cues, beats/holds, and director-only notes. The **"Pick from Hamlet…"** button opens the full Shakespeare text — search by character or word, tap a line to add it as a cue. Export as `.understudy` JSON to share. Autosave means your work survives every relaunch.

### Audience  *(iPhone)*
The show comes to you. Site-specific theater as a finished product: a big "Begin" card, a progress bar across the whole journey, stripped-down cue presentation (director notes are hidden, light cues narrate themselves in prose). Over the wire you're an `observer` so the director can see your position without you affecting the main cueing logic.

---

## Getting started — 30 seconds to Hamlet

1. Open `Understudy.xcodeproj` in Xcode 15.4+.
2. Pick any iOS simulator or device → **Run**.
3. On first launch, pick **Perform**.
4. Allow camera permission. The app opens with a five-mark Hamlet opening (Elsinore battlements) pre-loaded — Francisco's post, Bernardo enters, center, Horatio arrives, the Ghost.
5. Walk toward the first glowing mark. When you arrive, your phone pulses and a light cue washes the screen cool blue. Francisco speaks.

That's all you need to feel the thing. If you have a Vision Pro handy, run the same scheme to a visionOS simulator — both sides find each other on Wi-Fi.

For Android, see **[QUICKSTART.md](QUICKSTART.md)**.

---

## What's in this repo

```
Understudy/                         Swift source (iOS + visionOS, one target)
├── Models/                         Pure value types — Pose, Mark, Cue, Blocking
├── Shared/
│   ├── AppMode.swift               Perform / Author / Audience enum
│   ├── BlockingStore.swift         @Observable state, mark entry → cue firing
│   ├── BlockingFile.swift          .understudy FileDocument + autosave
│   ├── CueFXEngine.swift           Plays SFX, publishes flash state
│   ├── DemoBlockings.swift         The bundled Hamlet 5-mark demo
│   ├── Script.swift                Full play model (Acts, Scenes, Lines)
│   ├── Version.swift               CFBundle version, shown in UI
│   └── WireCoding.swift            JSONEncoder/Decoder with ISO-8601 dates
├── Networking/
│   ├── Transport.swift             Protocol — swappable MPC / WebSocket
│   ├── MultipeerTransport.swift    Apple-to-Apple on LAN
│   ├── WebSocketTransport.swift    Goes through /relay/server.py for Android
│   └── SessionController.swift     Wires store mutations to the wire
├── iOSApp/
│   ├── PerformerView.swift         Teleprompter + settings
│   ├── AuthorView.swift            Tap-to-place + inline mark editor
│   ├── AudienceView.swift          Self-paced tour
│   ├── ModeSelector.swift          First-launch picker
│   ├── ScriptBrowser.swift         Hamlet picker → .line cues
│   ├── ARPoseProvider.swift        ARKit → Pose
│   └── AR/ARStageContainer.swift   RealityKit scene with floor-anchored marks
├── VisionOS/
│   ├── DirectorControlPanel.swift  Floating window — room, transport, marks
│   └── DirectorImmersiveView.swift RealityKit stage with ghost + light wash
└── Resources/
    └── hamlet.json                 Full play, parsed from Project Gutenberg

android/                            Android Studio project (Kotlin + Compose + ARCore)
relay/                              Python WebSocket relay (one file, one dep)
scripts/                            parse_hamlet.py — how Resources/hamlet.json is made
test-fixtures/                      Canonical JSON for wire-format round-tripping
PROTOCOL.md                         The single source of truth for the wire format
QUICKSTART.md                       How to run the whole stack on a LAN
```

### Architecture at a glance

- **Single Swift target** builds for iOS and visionOS — `#if os(iOS)` / `#if os(visionOS)` routes the view.
- **Models are pure value types**, `Codable`, `Sendable`, `nonisolated`. They cross actor boundaries trivially and serialize trivially.
- **`BlockingStore` is an `@Observable` MainActor**. Mark entry enqueues `FiredCue`s into `cueQueue`; `CueFXEngine` drains the queue and actually does things (system sounds, screen flashes, visionOS stage wash).
- **`Transport` protocol** abstracts the wire. `MultipeerTransport` for pure Apple (Bonjour `_und-stage._tcp`, no server needed). `WebSocketTransport` for mixed environments including Android, via the relay.
- **`WireCoding`** is the shared `JSONEncoder`/`Decoder` with ISO-8601 dates — cross-platform safe.
- **Cue firing on transition edge** — cues fire on mark *entry*, not every frame the performer is inside the radius. No re-triggering when you wiggle.
- **Autosave on every mutation** — `addMark` / `updateMark` / `removeMark` / `addCue` / `stopRecording` / import / snapshot sync all persist to UserDefaults.

### Wire format

See [PROTOCOL.md](PROTOCOL.md). Short version: every message is a JSON `Envelope` carrying a `NetMessage` enum variant. Swift's default Codable emits enum cases as `{"caseName": {"_0": value}}` for unlabeled and `{"caseName": {"label": value}}` for labeled associated values — Kotlin matches with a polymorphic adapter in `android/app/src/main/java/agilelens/understudy/net/Envelope.kt`. Round-trip fixtures in `test-fixtures/` catch drift.

### Running the relay

```bash
cd relay
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 server.py
# Understudy relay starting on ws://0.0.0.0:8765
```

Then in every app's Settings → Transport → WebSocket, enter `ws://<relay-host-lan-ip>:8765`.

---

## Roadmap

### v0.1  ·  Foundation
- iOS performer (ARKit + haptics + teleprompter)
- visionOS director (RealityKit + tap-to-place + sequence ribbon)
- Multipeer sync of marks and performer positions
- Cue editor (lines, notes)
- Walk recording (stored on `Blocking` as `reference`)

### v0.2  ·  Theater that fires + Android
- iPhone AR stage view — live camera with floor-anchored marks
- Playback ghost — replay recorded walks as translucent AR avatars
- SFX cues play system sounds (bell / thunder / chime / knock / applause)
- Light cues flash the phone + tint the immersive visionOS stage
- **Android performer** — ARCore world tracking + OkHttp WebSocket
- **WebSocket relay** — Python server, room-scoped broadcast

### v0.3  ·  iPhone goes solo
- **Three iPhone modes** — Perform, Author, Audience. First-launch picker, switchable from Settings.
- **Author mode** — tap the floor to drop marks, tap a mark to open inline editor. Full cue library (line / sfx / light / wait / note) without an AVP.
- **Audience mode** — self-paced walk through a finished blocking; hides director notes; progress bar.
- **Save / load `.understudy` blockings** — fileExporter + fileImporter; pretty-printed JSON identical to the wire format.
- **Autosave** to UserDefaults on every mutation.
- **Bundled Hamlet 5-mark demo** — Elsinore battlements pre-loaded on first launch.

### v0.4  ·  The script
- **Full Hamlet bundled** — 5 acts, 20 scenes, 1108 lines of dialogue, 217 stage directions, parsed from Project Gutenberg #1524. Lives in `Resources/hamlet.json` (~330KB).
- **Script Browser** in Author mode — tap a line, it's on the mark. Search by character or word. Scene filter menu. Already-used lines show a green check.
- **Structured `PlayScript` model** — open to more plays via `Scripts.all`; see `scripts/parse_hamlet.py` for the parser.

### v0.5  ·  Drop a whole scene, preview a cue, see the script in space
- **Drop Whole Scene** — one-tap in the Script Browser auto-lays out a zig-zag path of marks along your current forward direction, bucketed by speaker (max 4 lines per beat), with stage directions attached as `.note` cues. A 20-beat scene becomes a walkable blocking in under a second.
- **Floating script panels on visionOS** — every mark in the immersive stage gets a translucent "manuscript page" floating at shoulder height nearby. The director sees the cues *in the room*, next to where the action happens. Ambient script-in-space — exactly what AVP is for.
- **Cue preview** — a ▷ next to every cue in the mark editor. Tap it to fire the cue immediately: hear the bell, see the amber flash, feel the beat. Essential for the authoring loop.

### Next up
- [ ] Shared-origin ceremony — QR-code anchor so every device agrees on where (0,0) is in the real room
- [ ] DMX / QLab bridge for real theater rigs on the director side
- [ ] Android catches up — Author mode + live AR camera (in flight)
- [ ] More bundled plays — Public-domain Chekhov, Beckett's shorter works
- [ ] TestFlight

## Project rules

- The version number is shown in every top bar (`AppVersion.formatted`) and must match `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `project.pbxproj`. Every build push bumps the version. No exceptions.
- `PROTOCOL.md` is authoritative. If you change a wire message, generate new fixtures with `test-fixtures/regenerate.sh` and update the Kotlin adapter in lockstep.
- `CLAUDE.md` captures project-level rules for agentic pair programming.

## License

All rights reserved for now — ping if you want to build on it or use it commercially.

Hamlet text is public domain (Project Gutenberg eBook #1524). `hamlet.json` is a restructured excerpt used as a bundled resource; the parser is in `scripts/parse_hamlet.py`.

## Credits

Designed and built by [Alex Coulombe](https://alexcoulombe.com) (Agile Lens) and Claude — iterated in ambitious afternoon sessions.
