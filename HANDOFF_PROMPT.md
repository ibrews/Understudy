# Understudy — Handoff Prompt (2026-04-30, end of overnight session 2)

## What's done this session

### v0.32 (35) — FULLY SHIPPED
- `NetMessage.recordingAdded(NamedRecording)` wired — broadcast on save, peers append idempotently
- iOS AR ghost orb tinted from `store.ghostAvatar` (wired `tintGhost()` into `ARStageContainer.sync`)
- visionOS cue-fire mark pulse (`syncCueFire()` in `DirectorImmersiveView`) + perimeter wash on `.light` cues
- iOS ghost playback scrub bar + loop mode toggle in `PerformerView.bottomBar`
- Both platforms uploaded to TestFlight: iOS UUID `f8520261...`, visionOS UUID `6f488537...`
- Branch: `overnight-review` — 11 commits ahead of main

### Wiki
- 5 screenshots embedded into wiki pages (first time they're actually visible)
- Mermaid diagrams for multi-device architecture + QLab/OSC flow (replaced ASCII art)
- 9-zone stage grid diagram added to Director-Guide
- Zig-zag Drop Whole Scene layout added to Author-Guide
- Pushed to https://github.com/ibrews/Understudy.wiki.git

---

## HyperFrames Promo Video — IN PROGRESS (Steps 1–6 done, Step 7 remains)

**Project dir:** `/tmp/understudy-video/`

### What's done (Steps 1–6)
- **Step 1 DONE**: `capture/` populated — 5 app screenshots, tokens, asset descriptions
- **Step 2 DONE**: `DESIGN.md` — dark theater identity, cyan/magenta/amber palette
- **Step 3 DONE**: `SCRIPT.md` — 55 words, 4 beats, ~14s of VO, A24 trailer register
- **Step 4 DONE**: `STORYBOARD.md` — beat-by-beat creative direction
- **Step 5 DONE**: `narration.wav` (13.7s, af_nova voice) + `transcript.json` (word timestamps)
- **Step 6 DONE**: All 4 composition HTML files built in `compositions/`

### Beat timing (from transcript.json)
| Beat | VO range | Composition start | Duration |
|---|---|---|---|
| Beat 1 — hook | 0.04–1.72s | 0.0s | 2.8s |
| Beat 2 — blocking | 1.76–6.88s | 2.2s | 6.5s |
| Beat 3 — ghost | 6.92–11.44s | 8.0s | 5.0s |
| Beat 4 — CTA | 11.48–13.40s | 12.5s | 4.5s |
| **Total** | | | **~17s** |

### What's left (Step 7)
1. **Build `index.html`** — the root composition that embeds the 4 beats with `data-composition-src` and the `narration.wav` audio:

```html
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;background:#000">
<div id="root" data-composition-id="root" data-width="1920" data-height="1080">
  <audio src="narration.wav" data-start="0" data-duration="13.7" data-volume="1.0" class="clip"></audio>
  <div data-composition-src="compositions/beat-1-hook.html" data-start="0" data-duration="2.8" data-track-index="0"></div>
  <div data-composition-src="compositions/beat-2-blocking.html" data-start="2.2" data-duration="6.5" data-track-index="0"></div>
  <div data-composition-src="compositions/beat-3-ghost.html" data-start="8.0" data-duration="5.0" data-track-index="0"></div>
  <div data-composition-src="compositions/beat-4-cta.html" data-start="12.5" data-duration="4.5" data-track-index="0"></div>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</body>
</html>
```

2. **Lint + validate**:
```bash
cd /tmp/understudy-video && npx hyperframes lint && npx hyperframes validate
```

3. **Snapshot** (visual QA — check each beat mid-frame):
```bash
npx hyperframes snapshot /tmp/understudy-video --at 1.4,5.5,10.5,14.5
```
View every snapshot. Fix anything that looks wrong before previewing.

4. **Preview**:
```bash
npx hyperframes preview
```
Open in browser, scrub through, QA everything. Fix issues.

5. **Render** (only when Alex says it looks good):
```bash
cd /tmp/understudy-video && npx hyperframes render --output renders/understudy-promo.mp4
```

6. **Save the URL** to MORNING_SUMMARY.md after preview/render.

### Composition file locations
```
/tmp/understudy-video/
├── index.html          ← STILL NEEDS TO BE BUILT
├── DESIGN.md           ✓
├── SCRIPT.md           ✓
├── STORYBOARD.md       ✓
├── narration.txt       ✓
├── narration.wav       ✓ (13.7s)
├── transcript.json     ✓
├── capture/            ✓ (5 app screenshots + tokens)
└── compositions/
    ├── beat-1-hook.html     ✓
    ├── beat-2-blocking.html ✓
    ├── beat-3-ghost.html    ✓
    └── beat-4-cta.html      ✓
```

### QA notes from Step 4 (review STORYBOARD.md for full intent)
- Beat 1: Black void, 3 cyan mark discs materialise, app icon floats. Canvas particle field.
- Beat 2: Split screen, 2 iPhone mockups tilted ±8°. Dialogue card "Who's there?" at 4.2s. Cue flash at 5.0s.
- Beat 3: Blurred AR room bg, magenta ghost SVG drifts, "Walk 1" types on, follower appears.
- Beat 4: Pure black, app icon scales in, "Understudy" types, "Walk the blocking." fades in, cyan disc pulses.

---

## Outstanding items for v0.33
- Merge `overnight-review` → `main` (10 commits ahead, all clean)
- Android wire-compat: mirror `Performer.avatar`, `Blocking.recordings`, `NetMessage.recordingAdded`
- Optional: spatial audio at mark positions in visionOS (described in CueFXEngine lastFire comment, not yet impl)

## Key file paths
| File | Location |
|---|---|
| Branch | `overnight-review` |
| Ship script | `bash scripts/ship-altool.sh [ios|visionos]` |
| Version bump | `bash scripts/bump-version.sh --marketing X.XX` |
| HyperFrames project | `/tmp/understudy-video/` |
| HyperFrames skill | `/Users/alex/.claude/skills/website-to-hyperframes/` |
| KB overview | `~/knowledge/projects/understudy/overview.md` |
