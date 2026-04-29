# Troubleshooting

If something isn't working, check this page first. Most issues fall into one of seven buckets.

---

## Black floating window on visionOS

> "I open the app on Vision Pro and I just see a small floating window. The room around me is empty — none of the marks or floor visualisation appear."

**Most common cause:** the immersive space didn't auto-open. Look at the Director Panel — there's a **green Open Stage** button at the top (the Quick Start strip). Tap it.

If you'd rather have the stage open automatically every time, the **Auto-open stage** toggle in the room row controls this (default ON in v0.30+; older builds had it OFF).

If Open Stage doesn't change anything (button stays green, no immersive content visible), check:
- The visionOS sim doesn't always render immersive content predictably; test on real Vision Pro hardware
- Look DOWN at the floor in front of you — the stage centre disc + perimeter rectangle live at floor level. They're invisible from straight-ahead viewing.
- The stage anchors at `[0, -1.0, -0.5]` from your head pose — meaning 1 m below + 0.5 m in front. Marks at floor level should be visible the moment you look at the floor.

If the room around you is genuinely empty after looking at the floor, please open an issue with screenshots.

---

## "Find your mark" but the guidance ring shows "—"

The phone has no marks loaded, OR the current mark sequence ID doesn't match any mark in the blocking.

**Check:**
1. Settings → About → confirm the blocking title (e.g. "Hamlet — Elsinore Battlements" for the bundled demo, or whatever you authored)
2. Tap the list icon → confirm marks are listed
3. If marks ARE listed but ring shows "—", you're not in any mark's radius and the system can't pick a "next" — try walking towards the first one or tap-and-fire it from the marks list

If the marks list is empty, you may have hit Clear in Author mode. Re-author or import a `.understudy` file.

---

## Calibration and connectivity

### Marks are in the wrong physical spot on a second device

Calibration. Every device's ARKit / ARCore origin is independent. Without calibration:
- Device A's `(0,0,0)` is wherever Device A started AR
- Device B's `(0,0,0)` is wherever Device B started AR
- A mark at `(1.2, 0, -0.5)` lives at different physical spots on each

**Fix:** use the QR target (Settings → "Show QR for performers to scan") and have every device point at it. Or use the manual compass ceremony (everyone stands at agreed-on stage centre, faces upstage, taps compass simultaneously).

The compass icon is green when calibrated, amber when not.

See [Multi-Devices § Calibration](Multiple-Devices#calibration) for the full workflow.

### "Peers: 0" but I have other devices in the room

For Multipeer: every device must be on the same Wi-Fi AND the same room code. Check both. Some networks (corporate, hotel) have **client isolation** enabled which blocks Bonjour-based peer discovery — switch to a personal hotspot or use the WebSocket relay.

For WebSocket: every device must point at the same relay URL (`ws://<host>:8765`). Test the relay is reachable: `curl http://<host>:8765` should return an HTTP 426 ("Upgrade Required") rather than a connection refused.

### "Peers: 1" then "Peers: 0" then "Peers: 1" — flapping

A flaky Wi-Fi router. Switch transports (Multipeer ↔ WebSocket via Settings) to see if one is more stable. If the relay is on Wi-Fi too, move it to wired Ethernet.

---

## Cues don't fire

### Cues fire on one device but not another

Cues fire **locally** — every device computes its own cue firings from pose. If your phone never enters a mark's radius, no cues fire on your phone. Check:
- Calibration is correct
- The mark's radius is reasonable (default 0.6 m; if you set it to 0.2 m you have to land within 20 cm)
- AR tracking quality (bottom-left of Perform mode) is "good"

### Cues fire twice in QLab

Two devices have outbound OSC enabled. Disable on all but one — typically just the director's headset.

### A `.line` cue doesn't display

Lines display in the **current cue card** (top centre of Perform view). Sound and light cues fire as side effects (audio + screen flash). If you only authored `.sfx` cues and no `.line` cues, you'll never see text appear — that's by design.

To attach a line, open the mark editor → Lines → **Pick from script…** or Add Custom Line.

---

## Voice mode doesn't follow my speech

### "Microphone permission denied"

Settings (iOS Settings, not Understudy's) → Understudy → Microphone → ON. Same for Speech Recognition.

### It hears me but doesn't scroll

The voice matcher needs **at least three consecutive words** matching your script's text. If you're paraphrasing, ad-libbing, or speaking softly, it won't scroll.

The "heard: …" caption at the bottom of the teleprompter shows what the recognizer heard. Use it to debug — if you see ___ where words should be, it's a recognition problem (mic too far, ambient noise, accent / dialect not well-supported).

### It says "We don't support voice mode on this device"

iOS 17+ requires `requiresOnDeviceRecognition = true` for privacy. Some iOS versions or device combos haven't downloaded the on-device language pack. Settings → General → Language & Region → confirm your primary language has on-device dictation available.

---

## Recording walks

### "REC" badge appears but nothing saved

Tap the stop button (next to the record button — they swap when recording). On stop, a green "Walk saved (X.Ys)" toast confirms.

If you see no toast, the recording was zero-length (you tapped stop before tapping record had a chance to register, or no AR pose was available).

### "I want to keep two reference walks"

The current model only keeps the most recent walk per blocking. Export the blocking to `.understudy` between recordings to preserve history.

This is on the v0.31 roadmap.

---

## Build / install issues (developers only)

### "BUILD FAILED — database is locked"

You're running two `xcodebuild` invocations against the same DerivedData simultaneously. Use `-derivedDataPath` to give each platform its own:

```bash
xcodebuild ... -derivedDataPath build/ios-sim -destination 'platform=iOS Simulator,...' build
xcodebuild ... -derivedDataPath build/visionos-sim -destination 'platform=visionOS Simulator,...' build
```

### Sim install hangs forever

Reboot the sim:

```bash
xcrun simctl shutdown <device-id>
xcrun simctl boot <device-id>
```

Then re-run install.

### TestFlight upload rejection: "missing supported platforms"

Common when first uploading a visionOS build to an App Store Connect record that was created iOS-only. Open App Store Connect → your app → App Information → Add Platform → visionOS. Then retry `scripts/ship-testflight.sh --platform visionos`.

---

## When all else fails

- Check `claude-progress.md` and `REVIEW_NEEDED.md` in the repo root — they track known issues and verification gaps that I'm aware of.
- File an issue at <https://github.com/ibrews/Understudy/issues> with screenshots and a brief description.
- For commercial use or feature requests, [email Agile Lens](mailto:info@agilelens.com).

---

## Where to next

- **[Glossary](Glossary)** — terms used throughout the wiki.
- **[Director's Guide](Director-Guide)** — back to the visionOS workflow.
