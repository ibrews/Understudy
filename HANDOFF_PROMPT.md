# Understudy — Handoff Prompt (2026-04-30, mid-session)

## Goal

Two things in flight when this session was force-stopped:

1. **Avatar + Multi-recording feature** ("the Understudy understudy feature") — a performer picks an avatar style + colours; a recording captures that avatar with the walk; an understudy can then load any named recording and chase a ghost rendered with the recording performer's avatar. Models + most UI is done; final wiring + iOS AR ghost render + recording broadcast not yet shipped.
2. **HyperFrames promo animation via the `/website-to-hyperframes` skill** — Alex asked for a killer animation that sells Understudy. Not started yet. Was scheduled after the avatar work finished.

## Status of v0.31 (the demo release before the avatar work)

- iOS + visionOS **shipped to TestFlight successfully** via `scripts/ship-altool.sh` with manual signing — both uploaded clean (UPLOAD SUCCEEDED, Delivery UUIDs in `/tmp/altool-{ios,vos}.log` and `/tmp/altool-ios2.log`). The right path was `xcodebuild -exportArchive (destination: export, signingStyle: manual)` then `xcrun altool --upload-app`. The previous combined `destination: upload` mode kept hanging on codesign — that's now bypassed.
- `scripts/ship-altool.sh` is the canonical TestFlight script. `ship-testflight.sh` is the legacy combined-mode one — keep but prefer altool.
- v0.31 (34) wiki at <https://github.com/ibrews/Understudy/wiki> is fully populated.

## What's done so far for the avatar feature

**Models (all committed-ready, build-clean)**
- `Understudy/Shared/Avatar.swift` — `Avatar` struct with `Style` enum (performer/dancer/ghost/minimal/villain/hero), 10-colour palette, `NamedRecording` struct with `legacyWalk:` migration init + `pose(at:)` interpolator. Hex → SIMD4<Float> helper.
- `Understudy/Models/CoreModels.swift`
  - `Performer` line 346: added `var avatar: Avatar?` field + custom `init(from:)` that decodes legacy payloads (no avatar key) cleanly.
  - `Blocking` line 403: added `var recordings: [NamedRecording]` + custom decoder that migrates `reference` → `recordings[0]` for old `.understudy` files.
- `Understudy/Shared/BlockingStore.swift` lines 150–245:
  - Added `selectedRecordingID`, `stopRecordingNamed(name:performerName:avatar:)`, `deleteRecording(id:)`, `renameRecording(id:to:)`, `activeRecording: NamedRecording?`, `ghostAvatar: Avatar?`. The legacy `stopRecording(saveAsReference:performerName:)` still exists for backward compat. `ghostPose(at:)` now reads from `activeRecording`, not `blocking.reference`.

**App-level wiring**
- `Understudy/UnderstudyApp.swift`: `@AppStorage` for avatarStyle/Primary/Secondary; on first appear, hydrate `localPerformer.avatar` from those defaults.

**UI views**
- `Understudy/Shared/AvatarPickerView.swift` — full sheet with live `AvatarPreview` Canvas (handles all 6 styles with bobbing animation), style grid, primary + accent colour swatches, persists on Save.
- `Understudy/Shared/RecordingsPickerView.swift` — list of recordings with avatar previews, tap to set selectedRecordingID, long-press for rename/delete.
- `Understudy/iOSApp/PerformerView.swift`:
  - Settings → Identity now has an avatar row that opens `AvatarPickerView` (line ~470-ish).
  - Bottom-bar record button: stops trigger a "Name this walk" alert (`showingNameRecordingAlert`) that calls `stopRecordingNamed`. Cancel discards via legacy `stopRecording(saveAsReference: false)`.
  - Ghost playback button uses `store.activeRecording` instead of `blocking.reference`. Long-press the ghost button → `RecordingsPickerView`.

**visionOS render**
- `Understudy/VisionOS/AvatarEntityBuilder.swift` — RealityKit Entity builder for all 6 avatar styles. Each style produces a ~1.7m-tall human-scale figure with body + head + accent (cape/horns/star/etc). Uses `UnlitMaterial` with `transparent` blending for the ghost style.
- `Understudy/VisionOS/DirectorImmersiveView.swift`:
  - `buildPerformerEntity(_:)` now calls `AvatarEntityBuilder.attach(avatar:to:)` with `perf.avatar ?? .defaultPick`. Performer origin is now floor (0), with name tag at 1.95m.
  - Initial `RealityView { content }` setup no longer creates a magenta-orb ghost — `ghostEntity` is now an empty placeholder rebuilt by `syncGhost()`.
  - `syncGhost()` rebuilds the ghost's avatar geometry when the active recording's avatar changes (via `renderedGhostAvatar` state). The ghost is forced into `.ghost` style (translucent) using the captured recording's colours — so playback always reads as "this is recorded" even with a captured avatar.

**Build status**
- Both iOS and visionOS were green at the most recent check (no errors, build/check4-vos was the last successful one). I had two builds queued (build/check5-ios and check5-vos) when the turn guard fired — those weren't started.

## What's next, in order

### A. Finish avatar feature (~30 min)
1. **Verify build is still green** — run on both platforms:
   ```bash
   cd /Users/Shared/Documents/xcodeproj/Understudy
   xcodebuild -project Understudy.xcodeproj -scheme Understudy \
     -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
     -derivedDataPath build/check-final-ios -quiet build 2>&1 | \
     grep -E "error:|BUILD SUCCEEDED|BUILD FAILED|^\*\*" | head -20
   xcodebuild -project Understudy.xcodeproj -scheme Understudy \
     -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.2' \
     -derivedDataPath build/check-final-vos -quiet build 2>&1 | \
     grep -E "error:|BUILD SUCCEEDED|BUILD FAILED|^\*\*" | head -20
   ```
2. **iOS AR ghost orb → avatar render**. `Understudy/iOSApp/AR/ARStageContainer.swift` lines ~113–129 has `makeGhostEntity()` that returns a magenta sphere + halo. Replace that with a 2D-projection-friendly version using `store.ghostAvatar?.style`. Simplest: keep a sphere + halo for `.ghost`/`.minimal`, use a stylised cone for `.dancer`, etc. **OR** just colour-tint the existing orb with the avatar's primary colour as a v0.32-minimum. The visionOS render is the headline; iOS can be the colour-tinted version for now.
3. **NamedRecording broadcast over the wire**. Currently recordings are saved locally only. To make recordings sync between peers, extend `Understudy/Networking/Transport.swift` `NetMessage` enum with a new case `recordingAdded(NamedRecording)`, send it from `BlockingStore.stopRecordingNamed` (call into `SessionController` like other broadcasts), and handle it in `SessionController.handle` by appending to `store.blocking.recordings` if not already present.
4. **Bump to v0.32** via `bash scripts/bump-version.sh --marketing 0.32`.
5. **Commit + push** with a thorough message covering avatars + named recordings + their wire-format compat.
6. **Ship to TestFlight** via `bash scripts/ship-altool.sh ios` then `... visionos` (the manual-signing path that worked tonight).

### B. The HyperFrames promo animation (~30–60 min)
1. Invoke the skill: call the `Skill` tool with `skill: "website-to-hyperframes"` and `args: "https://github.com/ibrews/Understudy"` (or maybe the Wiki URL — the skill should prompt for what it needs).
2. **QA the result before claiming done.** Alex specifically warned about past mistakes here. The skill returns a video; verify it actually plays, looks sharp, and represents Understudy well. If it pulls weird text or screenshots, regenerate with a different source URL.
3. If a stylistic input is needed, the README at `/Users/Shared/Documents/xcodeproj/Understudy/README.md` is the canonical pitch — it has the architecture diagram, the "Who this is for" table, screenshots in `Screenshots/*.png`, the v0.30 + v0.31 changelog with feature highlights.
4. Save the resulting URL to MORNING_SUMMARY.md so Alex can find it.

### C. Optional polish if time
- **Cue-fire animations on visionOS immersive stage** — half-built scaffolding in `CueFXEngine.swift` already: `lastFire: CueFireEvent?` is observable. Wire `DirectorImmersiveView` to react: pulse the active mark on cue, particle burst on `.sfx`, screen-perimeter wash on `.light` (not just the existing centre orb).
- **Spatial audio at mark positions** — RealityKit's `entity.prepareAudio(_:)` with the bundled WAV files at the mark entity. Replace `playSFX(named:)` in CueFXEngine with a path that asks the immersive view for the entity, attaches audio there.

## Open questions / blockers

- **None known.** The avatar feature is straightforward extension. The HyperFrames skill is unfamiliar so QA matters.
- **iPhone v0.31 install** still blocked by dev disk image not mounting since the phone reboot/unplug. Alex needs to plug the phone in once and let Xcode mount the image. Same for Vision Pro device install.
- The `ship-altool.sh` script has been validated — both platforms shipped tonight. No more cert/profile drama expected.

## Verification commands

```bash
cd /Users/Shared/Documents/xcodeproj/Understudy

# 1. Builds clean on both platforms
xcodebuild -project Understudy.xcodeproj -scheme Understudy \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -derivedDataPath build/check-handoff-ios -quiet build

xcodebuild -project Understudy.xcodeproj -scheme Understudy \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.2' \
  -derivedDataPath build/check-handoff-vos -quiet build

# 2. Sim install + screenshot (both are booted from earlier)
xcrun simctl install BE67601C-CD6F-4792-939D-F84BEB510FA2 \
  build/check-handoff-ios/Build/Products/Debug-iphonesimulator/Understudy.app
xcrun simctl launch BE67601C-CD6F-4792-939D-F84BEB510FA2 agilelens.Understudy
xcrun simctl io BE67601C-CD6F-4792-939D-F84BEB510FA2 screenshot \
  /tmp/understudy-v032-launch.png

# 3. (When ready) ship to TestFlight — both platforms
source ~/.zprofile
bash scripts/ship-altool.sh ios
bash scripts/ship-altool.sh visionos

# 4. Branch state
git log main..overnight-review --oneline | head -30
```

## Branch + commits

- Branch: `overnight-review`
- Pushed up through `805786a docs(v0.31): README changelog + MORNING_SUMMARY for the demo release`
- Local uncommitted changes: ~9 new/modified files for the avatar feature (Avatar.swift, AvatarPickerView.swift, RecordingsPickerView.swift, AvatarEntityBuilder.swift, modified CoreModels/BlockingStore/PerformerView/DirectorImmersiveView/UnderstudyApp). `git status` will show them — none are committed yet.

## File-and-line cheat sheet

| File | Key lines | What's there |
|---|---|---|
| `Understudy/Shared/Avatar.swift` | new file | Avatar + Style enum + palette + NamedRecording |
| `Understudy/Models/CoreModels.swift` | 346–397 | Performer.avatar + custom decoder |
| `Understudy/Models/CoreModels.swift` | 422, 469 | Blocking.recordings + legacy migration |
| `Understudy/Shared/BlockingStore.swift` | 150–245 | stopRecordingNamed, activeRecording, etc |
| `Understudy/Shared/AvatarPickerView.swift` | new file | Sheet + AvatarPreview Canvas |
| `Understudy/Shared/RecordingsPickerView.swift` | new file | List + rename/delete |
| `Understudy/VisionOS/AvatarEntityBuilder.swift` | new file | RealityKit entity per style |
| `Understudy/VisionOS/DirectorImmersiveView.swift` | 122–135, 656–690, 706–745 | Avatar rendering + ghost rebuild |
| `Understudy/UnderstudyApp.swift` | adjacent to roomCode @AppStorage | Avatar persistence |
| `Understudy/iOSApp/PerformerView.swift` | settings + bottom bar + body | Avatar row, name-recording alert, recordings picker |
