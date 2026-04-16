# Understudy — TestFlight Copy

Drafts for the public-ish strings that show up in TestFlight + eventually the App Store. Paste the relevant sections into App Store Connect.

---

## App name (30 char max)

> Understudy

## Subtitle (30 char max)

> Spatial teleprompter for stage + film

Alternatives that also fit:
- `Rehearsal in your pocket`
- `Walk the blocking. Go the show.`
- `AR theater, in your room`

## Promotional text (170 char max)

> Turn any room into a programmable stage. Place blocking marks in AR, attach lines from bundled Shakespeare + Chekhov + Wilde, and run your show from the performer's voice.

## Beta App Description (4000 char max)

> **Understudy is a multiplayer spatial-theater tool.** A director wearing Apple Vision Pro places blocking marks on the floor — actual points in 3D space — and attaches lines, sound cues, light cues, and beats to each one. Performers hold iPhones (or Android) that become smart teleprompters: walk onto a mark, your phone pulses, the next line appears, the sound fires.
>
> Five plays are bundled: Hamlet, Macbeth, A Midsummer Night's Dream, Chekhov's The Seagull, and Wilde's The Importance of Being Earnest. Drop a mark at Francisco's post, open the Script Browser, tap Bernardo's "Who's there?" — it's on the mark. Search, filter by scene, drop a whole act at once.
>
> **The show runs itself.** Voice mode uses on-device speech recognition to follow you through the script in karaoke cyan as you read. When you finish a line, the mark's remaining cues fire automatically — thunder rolls, stage lights change, director notes flash. No tapping. No GO button.
>
> **Real-world pro integration.** OSC bridge sends `/understudy/cue/line`, `/understudy/cue/sfx`, `/understudy/cue/light` over UDP to QLab or any show-control system. Bidirectional: QLab can trigger Understudy back. LiDAR room scanning (iPhone Pro) + shared-origin calibration means three devices in one room actually agree on where Mark 3 is.
>
> **Also a film-scouting tool.** Author mode has an actor/camera mark toggle. Drop virtual camera marks with real lens specs (14/24/35/50/85/135mm on full-frame); a live viewfinder overlay shows exactly what each lens would frame from where you're standing. Walk a scouted location, capture the mesh, ghost it into your rehearsal room in AVP.
>
> Pre-release. Ship your bug reports to info@agilelens.com.

## What to test (2000 char max, TestFlight-specific)

> **Rough edges welcome — this is the first build that's left my desk.**
>
> Please try:
> 1. First launch → pick Perform mode. Walk to the five marks of the pre-loaded Hamlet scene. Does the teleprompter follow you?
> 2. Tap the compass in the top bar, stand at stage center facing upstage, tap "Set Origin Here." Get a friend on another iPhone to do the same from the same spot. Do you see the same marks in the same places?
> 3. Author mode → tap the floor to drop a mark → edit its cues with "Pick from Hamlet…" → toggle to Perform mode and walk it.
> 4. Open the teleprompter (📜 button), tap 🎤, read a line aloud. Does the cyan highlight follow your voice? Does 🔥 fire the mark's SFX / light cues when you finish a line?
> 5. If you have a Vision Pro: open the director scene, tap in 3D to place marks, watch the phone performer's ghost appear.
> 6. If you have QLab: Settings → OSC Bridge → point at your QLab machine's LAN IP. Do your cues trigger QLab's stack?
>
> What I'm NOT sure works yet:
> - Multi-iPhone co-location (needs real-world testing with 2+ devices)
> - LiDAR scanning on older iPhone Pros (tested on 15 Pro only)
> - Android ↔ Apple interop over the relay (code is symmetric, not yet run end-to-end)
> - TestFlight on visionOS (needs separate archive upload; see HANDOFF_TESTFLIGHT.md)
>
> File issues with device model, iOS version, and a 10-sec screen recording where possible. Or just DM me.

## Feedback email

> info@agilelens.com

## Marketing URL

> https://github.com/ibrews/Understudy

## Support URL

> https://github.com/ibrews/Understudy/issues

## Privacy Policy URL

> https://github.com/ibrews/Understudy/blob/main/PRIVACY.md

(You'll need to write `PRIVACY.md` before first upload — draft below.)

---

## Privacy policy draft — `PRIVACY.md`

Save this alongside the README. App Store Connect requires a public URL.

```markdown
# Privacy Policy — Understudy

_Last updated: 2026-04-16_

Understudy is a spatial rehearsal tool. This policy describes what data it touches.

## What happens on your device
- **Camera feed** — used for AR world tracking (ARKit / ARCore). The feed is
  never recorded, transmitted, or stored.
- **Microphone + speech recognition** — used only when you turn on "Voice
  mode" in the teleprompter. Recognition runs entirely on-device (`SFSpeech
  Recognizer` with `requiresOnDeviceRecognition = true`). Spoken audio and
  transcripts never leave your phone.
- **LiDAR mesh (iPhone Pro)** — captured only when you tap "Scan room" in
  Author mode. Stored locally as part of the blocking document.

## What we share with other devices
- When you join a session, Understudy broadcasts your in-app pose, your
  display name, and the current blocking document to every device in the
  same room code. This happens over Multipeer Connectivity (LAN only) or
  via a WebSocket relay you configure.
- If you enable the OSC bridge, fire-event metadata (cue text, mark name,
  light color) goes to the host:port you configure. Typically QLab or
  another show-control system on your LAN.
- Fleet monitoring: when a session starts, Understudy advertises
  `_agilelens-mon._tcp` over Bonjour. Observers on your LAN (Mission Control
  app) can see pose updates and player joins. This is opt-out via
  Settings → Transport.

## What we do NOT do
- No analytics SDKs.
- No crash reporters.
- No user accounts.
- No server-side storage.
- No ads.

## Contact

info@agilelens.com — if something here doesn't describe your experience.
```

---

## Screenshots

TestFlight and the App Store both need screenshots eventually. Not required for internal TestFlight testing. When you're ready:

- **iPhone 15 Pro** (1290 × 2796, portrait) — required set: teleprompter with karaoke active, author mode with a mark dropped, perform mode showing AR stage, settings.
- **iPad Pro 13"** (2048 × 2732) — same four, optional.
- **Apple Vision Pro** (3840 × 2160) — director panel with marks + ghost avatar, QR target window, room scan ghosted.

The 60-second App Preview video is optional for TestFlight. If you make one later, the voice-driven cue firing demo (walk to the Ghost's mark, speak the line, watch thunder fire) is the shot.
