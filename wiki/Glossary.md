# Glossary

Terms used throughout this wiki and inside the app.

---

### Actor mark
A blocking position for a performer. Renders as a glowing cyan disc on the floor. When a performer enters its radius, the mark's cues fire. Contrast with [camera mark](#camera-mark).

### AR (Augmented Reality)
Computer-generated content overlaid on the real world via the device's camera. On iPhone, this is ARKit; on Android, ARCore. Understudy uses AR to anchor marks to the real floor.

### Author mode
The iPhone mode where you build a blocking — drop marks, attach cues, pick lines from the bundled plays. See [Author's Guide](Author-Guide).

### Audience mode
The iPhone mode where you walk a finished blocking as a self-paced AR experience. See [Audience Mode](Audience-Mode).

### Blocking
The whole document. A blocking has a title, a list of marks (in sequence), an optional reference walk, an optional room scan, and optional props. Persists as a `.understudy` JSON file on disk.

### Bonjour
Apple's local-network discovery protocol. Understudy advertises itself as `_und-stage._tcp` so Apple devices on the same Wi-Fi find each other automatically (see [Multipeer](#multipeer)).

### Calibration
The shared-origin transform that puts every device's marks in the same physical space. Without calibration, mark `(1.2, 0, -0.5)` is in different real-world spots on every device. With calibration, it's in the same spot everywhere. See [Multi-Devices § Calibration](Multiple-Devices#calibration).

### Camera mark
A virtual tripod placed in real space, with a real lens spec (focal length, sensor, height, tilt). Used for film pre-viz and location scouting. Renders as an amber disc with a tripod, camera body, and FOV wedge. See [Camera & Film Mode](Camera-and-Film-Mode).

### Compass
The icon in every mode's top bar that triggers calibration. Green when calibrated, amber when not. Tap it to set the current device pose as "stage centre, facing upstage."

### Cue
A thing that fires when a performer enters a mark. Five kinds:
- **`.line`** — dialogue (with an optional character name)
- **`.sfx`** — a sound effect (one of 5 named system sounds)
- **`.light`** — a colour wash + intensity (also fires DMX if configured)
- **`.wait`** — a programmed pause (a hold)
- **`.note`** — director-only text (hidden from audiences)

### Director (role)
The person wearing Apple Vision Pro who runs the rehearsal. Sees the immersive stage with marks, performer ghosts, and floating script cards. See [Director's Guide](Director-Guide).

### DMX / sACN
The lighting protocol that drives real fixtures. **DMX** is the wire format (channels of intensity values); **sACN (E1.31)** is the way to send DMX over Ethernet. Understudy can output sACN packets when `.light` cues fire. See [DMX-Lighting](DMX-Lighting).

### Drop Whole Scene
The Script Browser feature that auto-lays out a zig-zag path of marks with every line in the scene pre-populated. Turns a 20-beat scene into a walkable blocking in under a second. See [Author's Guide § Script Browser](Author-Guide#the-script-browser).

### FOV (Field of View)
The horizontal angle a camera lens captures. Computed from focal length and sensor width. Camera marks in Understudy show their FOV as an amber wedge spreading 3 m from the lens.

### Ghost (avatar)
The magenta orb that represents another performer in the immersive stage. Each ghost has a name tag floating above it.

### Ghost (playback)
A magenta orb in AR that traces the recorded reference walk. Late-joining performers can chase it to learn the blocking.

### GO (cursor)
A stage-manager-style cue advance. Independent of where performers physically are. The visionOS director panel has a big red GO button (keyboard shortcut: Return). The OSC bridge can also receive `/understudy/go` from QLab.

### Immersive Space
The visionOS rendering layer that overlays content into the wearer's whole environment. In Understudy, the Immersive Space contains the stage floor, marks, performer ghosts, props, and floating script cards. See [Director's Guide](Director-Guide#what-happens-on-launch).

### LiDAR
The depth sensor in iPhone 12 Pro and later iPhones. Understudy uses it to capture room-scale meshes via ARKit's scene reconstruction. See [Room Scanning](Room-Scanning).

### Mark
A blocking position. Floor-anchored, has a name, radius, sequence index, position, and a list of cues. Two kinds: [actor mark](#actor-mark) and [camera mark](#camera-mark).

### Mission Control
Agile Lens's fleet-wide monitoring app for multiplayer XR sessions. Understudy advertises itself on Mission Control's Bonjour service so observers can see live pose, room scan mesh, and player joins/leaves alongside other multiplayer apps.

### Multipeer (MPC)
Apple's peer-to-peer networking framework. Used for Apple-only sessions on the same LAN. Auto-discovers via Bonjour, no setup needed. Doesn't support Android. See [Multi-Devices](Multiple-Devices#multipeer-apple-only-on-a-lan).

### OSC (Open Sound Control)
A network protocol for show control. Understudy's OSC bridge sends `/understudy/cue/...` messages when cues fire (outbound, to QLab) and listens for `/understudy/go` (inbound, from QLab). See [QLab and OSC](QLab-and-OSC).

### Perform mode
The iPhone mode where you walk the blocking — guidance ring, teleprompter, haptic pulses on mark entry. See [Performer's Guide](Performer-Guide).

### Performer (role)
A person walking the blocking with a phone. iPhones and Android phones both work. Their pose is broadcast as a magenta ghost to the director.

### Pose
A rigid-body transform: position (x, y, z) + yaw rotation. Marks have poses (where they live in the room). Performers have poses (where they currently are).

### Preview Show
A delight feature in the visionOS director panel: walks the GO cursor through every actor mark in sequence, firing cues at 2.5 s per beat. Lets a director rehearse the cue stack with no performers in the room.

### Prop
A set-construction placeholder — a coloured cube, sphere, or cylinder dropped in the immersive stage to represent furniture, walls, doors. Useful for pre-viz before the real set is built.

### QR Target
A printed or on-screen QR code with payload `understudy://calibrate`, displayed at 210 mm wide. Performer phones detect it via ARKit / ARCore image tracking and auto-calibrate. The most reliable calibration method.

### Reference walk
A recorded version of the director's "ideal" walkthrough. Saved as part of the blocking. Can be played back as a magenta ghost. Late-joining performers can chase it.

### Room code
A short string in `Settings → Room` that scopes the multiplayer session. Devices with matching room codes connect; mismatched codes don't. Default is `rehearsal`.

### Room scan
A LiDAR-captured mesh of a real room. Saved as part of the blocking. Renders as a translucent cyan wireframe ghost. See [Room Scanning](Room-Scanning).

### Sequence index
The integer ordering of marks in a blocking. Actor marks have indices 0, 1, 2, … in the walk order. Camera marks have index `-1` to bypass the walk sequence.

### Stage area / 9-zone grid
The theatrical convention of dividing a stage into 9 zones: DSL (downstage left), DSC (downstage centre), DSR, CSL, CS (centre stage), CSR, USL, USC, USR. Understudy's grid overlay shows these as coloured tiles on the floor.

### Tabletop mode
A visionOS feature that scales the immersive stage to ~12% and floats it at table height. Lets the director review the whole blocking from above without walking the floor.

### Teleprompter
The full-screen karaoke-style script view. Past text dimmed grey, active 30-char window cyan, future text white. Four scroll inputs: manual drag, auto-scroll, voice match, mark follow. See [Performer's Guide § Teleprompter](Performer-Guide#teleprompter).

### Transport
The networking layer. Two options: [Multipeer](#multipeer-mpc) (Apple-only, LAN) and [WebSocket relay](#websocket-relay) (mixed platforms, can traverse internet). Switch via Settings.

### Understudy
The whole app. Also the bundled `.understudy` file format — pretty-printed JSON identical to the wire format.

### Visible mark / hidden mark
"Visible" and "hidden" aren't formal app terms — but in conversation, marks with a sequence index ≥ 0 are "visible" in the walk order; marks with `-1` (camera marks) are "hidden" from the teleprompter and audience progress.

### Voice mode
Teleprompter feature that uses on-device speech recognition to follow the performer's voice. The cursor advances to match the spoken words. See [Performer's Guide § Voice mode](Performer-Guide#3-voice-mode).

### WebSocket relay
A Python server (in `relay/` of the repo) that rebroadcasts Understudy JSON between connected clients. Required for sessions including Android, or for cross-network rehearsal. See [Multi-Devices § WebSocket relay](Multiple-Devices#websocket-relay-mixed-platform-remote-rehearsal).

### Wire format
The JSON shape of every Understudy message and document. Codified in `PROTOCOL.md` in the repo. The same format serialises:
- Live network messages (between devices)
- `.understudy` files on disk
- Test fixtures in `test-fixtures/` for round-trip verification

### Yaw
Rotation about the vertical axis. Used in poses to indicate "facing direction." Yaw=0 in Understudy means facing along the −Z axis (the upstage direction in theatrical convention).

---

## Where to next

- **[Home](Home)** — back to the wiki index
- **[Quick Start](Quick-Start)** — try the 90-second tutorial
