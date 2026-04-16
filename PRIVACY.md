# Privacy Policy — Understudy

*Last updated: 2026-04-16*

Understudy is a spatial rehearsal tool. This policy describes what data the app touches, where, and why.

## What happens on your device

- **Camera feed.** Used for AR world tracking (ARKit on iOS/visionOS, ARCore on Android). The feed is never recorded, never transmitted, and never stored. It feeds the tracking engine in memory and is discarded every frame.
- **Microphone + speech recognition.** Used *only* when you enable "Voice mode" in the teleprompter. Recognition runs entirely on-device — `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` on Apple platforms, Android's `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE = true` where supported. Audio and transcripts never leave your phone.
- **LiDAR mesh.** Captured only when you tap "Scan room" in Author mode on a LiDAR-capable iPhone Pro. Stored locally as part of the blocking document.
- **Blocking documents** (`.understudy` JSON files). Stored locally. Shared only when you explicitly Export via share sheet.

## What we send to other devices

When you join a rehearsal session, Understudy broadcasts:

- Your in-app **pose** (position + yaw in the shared blocking frame)
- Your **display name** + device role
- The current **blocking document** (marks, lines, cues)

…to every device in the same room code, over one of:

- **Multipeer Connectivity** (LAN-only, Apple ↔ Apple, auto-discovered via Bonjour `_und-stage._tcp`)
- A **WebSocket relay** you configure in Settings — runs on a host of your choice, not ours. We never host a relay for you.

When you enable the **OSC bridge**, fire-event metadata (cue text, mark name, light color, wait duration) goes to the UDP host:port you configure — typically QLab or another show-control system on your LAN.

When you enable **fleet monitoring** (on by default in a rehearsal session), Understudy advertises `_agilelens-mon._tcp` over Bonjour so other Agile Lens apps' Mission Control views can observe your session. Disable via Settings → Transport if you don't want this.

## What we do NOT do

- No analytics SDKs.
- No crash reporters.
- No user accounts.
- No server-side storage under Agile Lens control.
- No ads.
- No third-party trackers.

## Third-party content

- Bundled Shakespeare texts (Hamlet, Macbeth, A Midsummer Night's Dream) — public domain via Project Gutenberg.
- Bundled Chekhov + Wilde texts (The Seagull, The Importance of Being Earnest) — public domain via Project Gutenberg.
- Open-source libraries: MultipeerConnectivity (Apple), ARKit (Apple), RealityKit (Apple), ARCore (Google, via Google Play Services), OkHttp, kotlinx-serialization. Their telemetry policies apply to the underlying system — we don't add any on top.

## Your rights

Since Understudy doesn't collect personal data, there's nothing to request, export, or delete on our end. Everything lives on your device; delete the app and it's gone.

## Contact

info@agilelens.com — if something here doesn't describe your experience, or if you have questions.
