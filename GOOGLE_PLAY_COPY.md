# Understudy — Google Play Copy

Drafts for the Play Console listing fields. Paste the relevant sections. Most overlap with `TESTFLIGHT_COPY.md`; Play has tighter length limits on some fields and different field names.

---

## App name (30 char max)

> Understudy

## Short description (80 char max)

> Spatial teleprompter for stage + film — blocking marks in AR, voice-driven cues

Alternates under 80:
- `AR theater rehearsal — walk your blocking, hear your cues`
- `Spatial rehearsal. Drop marks in AR. Run the show from your voice.`

## Full description (4000 char max)

> **Understudy is a multiplayer spatial-theater tool.** A director wearing Apple Vision Pro or holding a phone places blocking marks on the floor — actual points in 3D space — and attaches lines, sound cues, light cues, and beats to each one. Performers hold phones that become smart teleprompters: walk onto a mark, your phone pulses, the next line appears, the sound fires.
>
> Five plays are bundled: Hamlet, Macbeth, A Midsummer Night's Dream, Chekhov's The Seagull, and Wilde's The Importance of Being Earnest. Drop a mark at Francisco's post, open the Script Browser, tap Bernardo's "Who's there?" — it's on the mark. Search, filter by scene, drop a whole act at once.
>
> **The show runs itself.** Voice mode uses on-device speech recognition to follow you through the script in karaoke cyan as you read. When you finish a line, the mark's remaining cues fire automatically — thunder rolls, stage lights change, director notes flash. No tapping. No GO button.
>
> **Real-world pro integration.** OSC bridge sends /understudy/cue/line, /understudy/cue/sfx, /understudy/cue/light over UDP to QLab or any show-control system. Bidirectional: QLab can trigger Understudy back. Shared-origin calibration means multiple devices in one room agree on where each mark is.
>
> **Cross-platform rehearsal.** Runs on Android phones, iPhones, iPads, and Apple Vision Pro — all in the same session over LAN. An Android XR projected-display companion lets AI glasses show just the next line in your eyeline.
>
> **Also a film-scouting tool.** Author mode has an actor/camera mark toggle. Drop virtual camera marks with real lens specs (14/24/35/50/85/135mm on full-frame); a live viewfinder overlay shows exactly what each lens would frame from where you're standing.
>
> Pre-release. Bug reports → info@agilelens.com.

## Release notes / "What's new" (500 char max, per release)

> Internal-testing build. Early cross-platform rehearsal: marks in AR, voice-driven cues, OSC bridge to QLab. Try the bundled Hamlet scene, scan a room, run a session with another phone. Bug reports to info@agilelens.com.

## Release notes — "What to test" (longer form, for the testers email)

> Rough edges welcome — this is the first Android build that's left my desk.
>
> Please try:
> 1. First launch → pick Perform mode. Walk to the five marks of the pre-loaded Hamlet scene. Does the teleprompter follow you?
> 2. Tap the compass in the top bar, stand at stage center, tap "Set Origin Here." Get a friend on another phone (Android or iPhone) to do the same from the same spot. Do you see the same marks in the same places?
> 3. Author mode → tap the floor to drop a mark → edit its cues with "Pick from Hamlet…" → toggle to Perform mode and walk it.
> 4. Open the teleprompter, tap the mic, read a line aloud. Does the cyan highlight follow your voice? Does the fire icon trigger the mark's SFX / light cues when you finish a line?
> 5. If you have QLab: Settings → OSC Bridge → point at your QLab machine's LAN IP. Do your cues trigger QLab's stack?
> 6. If you have a pair of Android XR AI-glasses paired to your phone: try the projected-display companion mode.
>
> What I'm NOT sure works yet:
> - Android ↔ iPhone co-location (code is symmetric, not yet stress-tested)
> - ARCore on non-Pixel / non-Samsung flagships (tested on Pixel 8 Pro only)
> - Projected-display mode (Android XR is brand new; the alpha library may misbehave)
>
> File issues with device model, Android version, and a 10-second screen recording where possible. Or just DM me.

## Contact email

> info@agilelens.com

## Website

> https://github.com/ibrews/Understudy

## Privacy policy URL

> https://github.com/ibrews/Understudy/blob/main/PRIVACY.md

## App category

> **Category**: Productivity
> **Tags**: Productivity · Tools · Entertainment (Play lets you pick up to 5)

---

## Graphics assets (required)

Play Console won't let you publish without these. Not blockers for the first `.aab` upload, but blockers for the testers actually finding it in Play Store.

- **App icon** — 512×512 PNG, 32-bit with alpha. Reuse the iOS 1024×1024 icon flattened to 512 with no alpha-masked corners; Play rounds corners itself.
- **Feature graphic** — 1024×500 PNG/JPG. One hero shot — e.g. a phone showing the teleprompter overlaid on an AR stage with two marks visible.
- **Phone screenshots** — at least 2, up to 8, 16:9 or 9:16, 320-3840 px per side. Suggested set (matches the iOS set in `TESTFLIGHT_COPY.md`):
  1. Teleprompter with karaoke cyan active
  2. Author mode with a mark dropped on the floor
  3. Perform mode showing AR stage with three marks
  4. Settings → OSC Bridge panel
- **7-inch + 10-inch tablet screenshots** — skip for internal testing.
- **Promo video** (YouTube URL) — skip for internal testing.

---

## Content rating answers (quick reference)

See `HANDOFF_GOOGLE_PLAY.md` Step 4c for the full questionnaire walkthrough. Summary:

- Category: Utility / Productivity / Communication
- Violence, sex, language, drugs, gambling: all No
- User-generated content / user-to-user sharing: **Yes** (LAN room codes share blocking docs — not a public feed, but honest answer is yes). Moderation: "None — LAN / room-code-scoped sharing only, no public feed or discovery."

Expected rating: PEGI 3 / ESRB Everyone.

---

## Data-safety form answer (quick reference)

See `HANDOFF_GOOGLE_PLAY.md` Step 4g and `PRIVACY.md`. Summary:

- **Data collected**: **None.** All camera / mic / LiDAR processing is on-device. Pose broadcasts go device-to-device on user-controlled LAN / relay.
- **Data shared**: **None** on Agile Lens's side. Blocking documents travel device-to-device when the user joins a session; OSC metadata travels to the UDP host the user configures.
- **Encryption in transit**: Bonjour/MPC is encrypted by default (Apple); user-configured wss:// relays may be TLS. Not universally true of plain ws:// — disclose if Google asks.
- **User deletion request flow**: N/A — nothing collected.
