# Room Scanning (LiDAR)

If your iPhone has LiDAR (iPhone 12 Pro or later, iPad Pro 2020+), Understudy can capture the room as a 3D mesh and replay it as a translucent ghost over your stage. The single most useful application: **scout a venue on location, then rehearse it in your studio with the venue overlaid on your studio floor.**

This guide walks you through capture, alignment, and the workflow that connects scouting and rehearsal.

---

## What you can do with a scan

- **Scout a venue once** — capture the geometry of a real performance space, send the scan to your director.
- **Rehearse remotely with venue context** — director loads the scan in their visionOS, sees a wireframe of the venue projected over their own room. Marks dropped during rehearsal land on the venue's geometry, not the studio's.
- **Align to a different room** — when you actually get to the venue, drag the scan ghost to align with the real walls. Marks placed against the scan now land on the venue's actual floor.
- **Dimensionally accurate camera coverage** — camera marks placed against a scan reflect the real walls and obstructions. A 35 mm shot at the back of a long room is different from a 35 mm shot at the back of a 4 m studio.

---

## Capturing a scan

In **Author mode** on a LiDAR-capable iPhone:

1. The bottom bar shows an extra **scan strip** with a "Scan room" button.
2. Tap **Scan room**. The button changes to "Scanning…" with a triangle counter.
3. **Walk around the space** slowly, panning the phone over walls, floor, ceiling. ARKit's scene reconstruction captures mesh anchors as you go. The triangle count ticks up.
4. When you've covered everything you want, tap **Finish**. A naming sheet appears.
5. **Name the scan** (e.g. "Brooklyn studio 4F", "Hall L — east wall"). Tap Save.

The mesh is captured, flattened into a single world-space mesh, and saved as part of the blocking. It travels over the wire to every connected device — visionOS director sees it as a translucent cyan wireframe ghost; iPhone performers see it overlaid on their AR feed.

---

## What "good capture" looks like

- **30,000+ triangles** for a typical room — under that, you're missing surfaces
- Walk slowly — under 0.5 m/s gives ARKit time to integrate new anchors
- Sweep the phone vertically (point at floor, then up at ceiling) every metre or two
- Capture corners and doorways carefully — they help alignment later
- Avoid mirrors and glass — they confuse the depth sensor

A complete capture of a small theatre takes 3–5 minutes.

---

## What it looks like after capture

```
┌───────────────────────────────────────────┐
│  ┌─ scan strip ──────────────────┐        │
│  │ 🟧 [Brooklyn studio 4F]       │        │
│  │ 38,412 tris • 184 KB • 🗑     │        │
│  └────────────────────────────────┘       │
└───────────────────────────────────────────┘
```

The strip shows the scan name, triangle count, file size, and a trash button to discard. A "Re-scan room" button replaces the current scan.

The scan is also visible:
- On the iPhone author's AR view as a cyan wireframe over the live camera feed
- On the visionOS director's immersive stage as a wireframe ghost

---

## Aligning a scan to a different room

This is where the scout-then-rehearse workflow lives.

When the visionOS director receives a scan from a remote performer, the scan lands at the visionOS coordinate origin — which means the venue's geometry is aligned to the *studio's* origin, not where the studio walls actually are.

To fix that, the director uses the **Scan Align** strip in the panel:

1. Toggle **Align** (the lock icon → unlock).
2. **Drag the scan ghost** in the immersive stage with a pinch — it translates on the floor plane.
3. **Rotate** with the ±15° buttons (or in visionOS 2.0+, with a simultaneous drag + rotate gesture).
4. Match the scan's walls to the studio's walls.
5. Re-lock.

The scan offset (`Pose`) broadcasts to every peer, so every device sees the aligned overlay without re-transmitting the mesh.

---

## How alignment is broadcast

The mesh itself is sent once (`roomScanUpdated` message). After that, only the alignment offset (`roomScanOverlay(Pose)`) is broadcast — a few bytes, not the full mesh.

This means a 200 KB scan that gets nudged 10 times during alignment doesn't re-transmit 2 MB of data. It's one mesh + 10 tiny offset updates.

---

## Mesh visibility

| Device | What it sees |
| ---- | ---- |
| iPhone (any) — capturing live | Cyan mesh anchors rendered against the live AR feed as ARKit captures them |
| iPhone (any) — saved scan, no live capture | Saved mesh rendered as a wireframe ghost over the AR feed |
| visionOS director | Translucent cyan wireframe in the immersive stage, draggable when alignment is unlocked |
| Android (currently) | Round-trips through wire format but doesn't render — Android's wireframe pipeline is a v0.31+ item |

---

## Tabletop + scan = scale model

Toggle **Tabletop mode** in the visionOS director panel with a scan loaded. The whole stage — including the scan — scales to ~12% and floats at table height.

You're now leaning over a literal scale model of the venue, with marks and props floating inside it. This is the closest thing to a virtual maquette we've shipped.

---

## Using the scan for camera coverage

Camera marks placed in a scanned room behave correctly relative to the venue's geometry:

- A 50 mm camera mark in a long narrow scan will frame differently from a 50 mm mark in a square scan, because the FOV wedge spreads against the actual walls.
- Walking around the scan ghost in tabletop mode shows you which camera positions are blocked by walls or columns.
- The visionOS director can drop multiple camera marks and see which ones hit the same key actor mark — useful when planning two-camera coverage.

---

## Limitations and gotchas

- **One scan per blocking.** You can replace it but not stack multiple scans.
- **No mesh editing.** Once captured, the scan is what it is. Re-capture if you missed a corner.
- **Material is a single ghost.** Walls, floor, furniture all render as the same translucent cyan — there's no semantic labelling.
- **iPhone Pro only.** Standard iPhones don't have LiDAR, so they can't capture (but they can render scans someone else captured).
- **ARKit's scene reconstruction is approximate.** Curves and corners may be slightly off. For dimensionally critical work, validate against a measured plan.

---

## Where to next

- **[Director's Guide § Room scanning](Director-Guide#room-scanning-lidar)** — visionOS-side workflow
- **[Camera & Film Mode](Camera-and-Film-Mode)** — using camera marks against scanned geometry
- **[Multi-Devices](Multiple-Devices)** — how scans propagate across the wire
