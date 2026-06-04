# Director's Guide (Apple Vision Pro)

The director sits at the centre of an Understudy session. Wearing Vision Pro, you see the floating control window, the immersive stage with all the marks, and ghost avatars for every performer in the room.

This guide walks you through what you'll see when you launch — and what every part of the panel does.

---

## What happens on launch

Open Understudy on visionOS. You'll see two things appear in your space at once:

1. **The Director Panel** — a floating window with the room name, a Quick Start strip, the marks list, and the transport controls. Roughly the size of an iPad, hovering at chest height.
2. **The Immersive Stage** — opens automatically. Look down at the floor in front of you and you'll see:
   - A **soft cyan rectangle** marking the playing area (4 m wide × 6 m deep).
   - A **glowing red puddle** at the stage centre — your origin.
   - A floating welcome card: *"Tap the floor to drop a mark."* (The card disappears the moment your first mark exists.)

If the stage didn't open automatically, the Quick Start strip has a green **Open Stage** button — tap it. You can also turn off auto-open from the Auto-open Stage toggle in the room row.

> **What if I see only the floating window and nothing on the floor?**
> Tap **Open Stage** once — the panel button now stays in sync with the system, so a single tap always reopens the stage, even after you've dismissed it with the Digital Crown or backgrounded the app. If it's still empty, see [Troubleshooting → Black floating window](Troubleshooting#black-floating-window-on-visionos).

---

## The Quick Start strip

Three big buttons at the top of the panel — the actions you'll reach for most often.

| Button | What it does |
| ---- | ---- |
| 🎭 **Open Stage / Close Stage** | Toggles the immersive space. When the stage is open, this becomes "Close Stage". |
| 📜 **Teleprompter** | Opens the karaoke script as its own floating window. Position it anywhere in your space. Tap to open the bundled play library. |
| ▶️ **Preview Show** | Walks the GO cursor through every actor mark in sequence at 2.5 s per beat. Cues fire as if a performer just walked on. **Use this to rehearse the cue stack with no performers in the room.** Press again to stop. |

---

## Immersion & hands

A strip below the room row gives you three **independent** controls:

- **Mixed / Full** — *Mixed* keeps passthrough so the stage overlays your real room (the default for rehearsing in a physical space). *Full* replaces the room with a photographic dark-studio environment (a CC0 HDRI) — good for focus, or for previewing in a featureless space.
- **Real Hands** — show or hide your real hands (passthrough).
- **Virtual Hands** — draw glowing markers on your tracked hands. These are a separate layer from your real hands, so you can show virtual hands while hiding your real ones, or any combination. (Visible on device; the Simulator has no hands to track.)
- **IBL** — turn on image-based lighting from the studio environment. Because Understudy's marks and avatars use a flat (unlit) theatrical style, this also shows a small row of test spheres (chrome → gold → glossy → matte) so you can see the environment lighting and reflections. Pairs naturally with **Full**.

## First-run walkthrough

The first time you open the Director Panel, a short walkthrough explains the stage, dropping marks, firing cues, and bringing in your cast. Replay it anytime with the **Tutorial** button in the panel footer — handy when you hand the headset to someone new.

---

## Dropping marks — tap the floor

In the immersive stage, simply **tap the floor** with your gaze + pinch. A cyan disc appears at the tap point. The mark is named "Mark N" by default and added to the running order.

Tap the disc again to open the mark editor (right inside the panel) where you can:
- Rename the mark
- Adjust radius (0.2 – 3.0 m)
- Add lines, sounds, lights, beats
- Pick lines from the bundled plays

A **floating script card** appears next to each mark, hovering at shoulder height. Each card shows the next line on that mark — a "manuscript page" you can read at a glance while you walk the room.

> **Snap to grid.** Toggle "Grid" in the stage toolbar to overlay a 9-zone theatrical grid (DSL, DSC, DSR, CSL, CS, CSR, USL, USC, USR). Toggle "Snap" to make new marks lock to zone centres within 0.7 m. Useful when you want clean stage geometry, not just real-room coordinates.

```
                    ↑  UPSTAGE  ↑
     ┌──────────┬──────────┬──────────┐
     │  USL     │   USC    │   USR    │
     │  (Up     │   (Up    │   (Up    │
     │  Stage   │  Stage   │  Stage   │
     │  Left)   │  Centre) │  Right)  │
     ├──────────┼──────────┼──────────┤
     │  CSL     │   CS     │   CSR    │
     │ (Centre  │ (Centre  │ (Centre  │
     │  Stage   │  Stage)  │  Stage   │
     │  Left)   │          │  Right)  │
     ├──────────┼──────────┼──────────┤
     │  DSL     │   DSC    │   DSR    │
     │  (Down   │  (Down   │  (Down   │
     │  Stage   │  Stage   │  Stage   │
     │  Left)   │  Centre) │  Right)  │
     └──────────┴──────────┴──────────┘
                    ↓  AUDIENCE  ↓
         Stage Right = audience's left
         Stage Left  = audience's right
```

---

## Tabletop mode

Toggle **Tabletop** in the stage toolbar. The whole stage scales down to ~12% and floats at table height in front of you. Lean over and inspect the entire blocking like a model. Tap-to-place is disabled in this mode (so you don't accidentally drop marks while reviewing).

Toggle off to return to full size.

---

## Props (set construction)

Toggle **Props** in the stage toolbar to enter prop placement mode. Pick a shape (cube / sphere / cylinder), tap the floor, and a coloured volume appears — a placeholder for furniture, walls, doors. Tap any prop to edit its name, size, and colour.

Use this to mark "couch goes here", "doorframe", "rake of the platform" before the real set is built.

---

## Rehearsal timer

Below the stage toolbar — a `00:00` strip with play / pause / reset. Lets you time how long a run-through takes. Persists across the rehearsal as long as the panel stays open.

---

## Marks list — the running order

Below the toolbar, a vertical list of every mark in sequence. Each row shows:
- The mark's number (its sequence index)
- Its name (e.g. "Francisco's Post")
- A summary of cues attached
- Position in metres

Tap a row to edit. Swipe-left to delete. The **+ Add** button drops a mark at the origin (useful for testing without entering the immersive space). The **CSV** button imports a stage manager's cue sheet — a CSV with `name, note` columns becomes a column of marks.

---

## Transport — playback the recorded walk

Below the marks list, when a `reference` walk is recorded, you'll see:
- A play / pause button
- A scrubbable timeline
- Time elapsed / total

Press play and the director sees a magenta ghost avatar moving through the recorded path. Useful for reviewing what a performer did, or for late-joining performers to scrub through a "ghost" they can chase.

---

## OSC and DMX — for cue stack integration

The bottom row of the room section has:
- **OSC → QLab** — when configured, every cue fired sends a `/understudy/cue/...` message to a listening QLab on your LAN. See [QLab and OSC](QLab-and-OSC).
- **GO** (red, big) — manually advances the cue stack. Same as a stage manager calling GO.
- **Back step** (orange) — moves back one cue.
- The visible **GO cursor** is independent of where performers are — useful when you want to drive the show ahead of (or behind) where the cast actually is.

DMX (sACN) lighting output is configured from the iOS Settings sheet on a Performer or Author device — not the visionOS panel. See [DMX-Lighting](DMX-Lighting).

---

## Calibrating with performers

When performers join your session over the local network, every device starts at its own AR origin. You need a **shared origin** so a mark dropped on the visionOS director's stage appears in the right physical spot on the iPhone performer's floor.

Two ways:

### Compass ceremony (manual)
1. Everyone stands at the agreed-upon stage centre.
2. Everyone faces upstage.
3. Everyone taps the **compass icon** in their app's top bar at the same time.

The compass turns green on each device. Now every mark is in the same coordinate frame on every device.

### QR target (automatic)
Open the **QR Target** window from the room row. A bright-white QR target appears (or print one — payload is `understudy://calibrate`, 210 mm wide). Performers point their phones at it; calibration happens automatically the moment the camera sees it.

The QR target is the more reliable option — exact position, no ceremony.

See [Multiple-Devices § Calibration](Multiple-Devices#calibration) for details.

---

## Room scanning (LiDAR)

If a performer with a LiDAR-capable iPhone (12 Pro or later) scans the rehearsal room, the visionOS director sees the captured mesh as a translucent cyan wireframe — a "ghost" of the location, draped over the real room.

Once the scan exists, a **Scan Align** strip appears in the director panel. Drag the ghost to translate, use the rotate buttons to align it with the real room. Lock it when done.

This is most useful when scouting a venue: scan the venue, then bring the scan back to your studio and rehearse with the venue's geometry overlaid on your studio floor.

See [Room-Scanning](Room-Scanning) for the full workflow.

---

## What you'll see when performers connect

Every connected performer appears as a **magenta ghost avatar** moving through the immersive stage in real time. Their name floats above their head.

Their currently-active mark glows brighter. When a performer enters a mark, you see the mark light up and (depending on cue type) hear the SFX, see a light wash, etc.

Across a room of three performers, you'll see three magenta ghosts on the stage. Across an Android-included session, the same — Android performers feed the same pose stream.

---

## Tips for first-time directors

- **Open the Teleprompter alongside the panel.** Drag it to your right, panel on the left. Now you see the script and the controls without context-switching.
- **Use Preview Show before rehearsal.** Walks every mark at 2.5 s per beat, fires every cue. You'll catch missing cues and mistimed lines before any performer arrives.
- **Tabletop mode is for reviewing, full-size is for blocking.** Don't try to drop marks in tabletop — you can't. Toggle off when you're ready to place again.
- **Save often.** Use the Author iPhone's Export to save a `.understudy` file to Files / iCloud. The visionOS panel doesn't have its own export yet — that's a limitation we'll fix in v0.31.

---

## Where to next

- **[Performer's Guide](Performer-Guide)** — what your cast sees on iPhone.
- **[Author's Guide](Author-Guide)** — building blockings and using the script library.
- **[Multiple-Devices](Multiple-Devices)** — Bonjour vs WebSocket, Android, mixed-platform sessions.
- **[Troubleshooting](Troubleshooting)** — when something doesn't work.
