# Audience Mode (iPhone)

Audience mode turns a finished blocking into a self-paced AR experience. The phone is your guide; you walk the path; the show comes to you.

This is the mode that turns site-specific theatre into something you can ship — anyone with an iPhone can experience the show after the curtain falls.

---

## What you'll see

The opening screen is a single big card:

> **Hamlet — Elsinore Battlements**
>
> Find Francisco's Post.
> When you're ready, begin.
>
> ▶ **Begin**

There's no setup. No performers. No director. Just you, a phone, and a finished blocking — either a director's recorded show or a piece authored specifically for audience mode.

---

## The walk

When you tap **Begin** and start moving:

- **Walking towards a mark** — the screen shows the next mark's name and your distance to it
- **Crossing into the mark's radius** — your phone pulses, the cue card slides up, and any sound / light cues fire
- **Lines** read in big serif type with character names in red monospace
- **Light cues** narrate as text instead of just flashing the screen — *"A blue light washes the space"* — so audience members understand the design intent
- **Director notes** are hidden — those are for the cast

A progress bar at the bottom shows how far through the show you are: *"3 of 12 marks"*.

---

## Scrubbing — jump to any beat

The progress bar is **interactive**. Tap or drag any spot to jump to that beat:
- The phone fires the cues for that mark immediately
- A small cyan label reads **"Scrubbing — tap Stop to release"**
- Tap **Stop** (bottom right) to release the scrub and return to position-based progression

This is great for:
- **Re-experiencing a moment** — the audience member who wants to hear that line again
- **Skipping a slow beat** — if a particular passage doesn't land, jump past it
- **Testing the show** — a director can scrub through the whole walk on a phone before the audience arrives

---

## Joining a live director's room

If the director is wearing Vision Pro and running a live rehearsal, audience phones can join the same session:

1. Settings → **Mode → Audience**
2. Settings → **Room** → enter the room code the director shares
3. Make sure **Transport** is set to whatever the director is using (Multipeer for Apple-only, WebSocket for mixed Apple + Android)
4. The director's marks now appear in real time on your phone

You're broadcast to the director as an `observer` — they see your position as a different-coloured ghost, but you don't affect cue firing for the cast.

---

## Tips for audience design

- **Don't author for audience mode like rehearsal.** Cut director notes. Replace ambiguous "blue light" cues with text the audience will read out loud or in their head. Treat the screen as the program note that arrives at the right moment.
- **Test scrubbing on a long show.** A 60-mark show might lose some audience members — make sure the scrub-to-beat lands gracefully and the progress bar reads cleanly.
- **Audio is the killer feature.** A pair of AirPods + a recorded voice actor + a 30-mark blocking = a self-paced one-person play. We recommend recording sound files outside Understudy (Voice Memos, GarageBand, Audacity), then attaching them as `.sfx` cues with custom names. (Custom audio files are a v0.31 feature; for now, the five built-in SFX are bell, thunder, chime, knock, applause.)
- **The audience sees what they're given.** They don't see the full script unless you also expose the teleprompter button. If you want the audience to be able to read every line in advance, leave the 📜 quote icon visible (it's there in the top bar by default).

---

## Where to next

- **[Performer's Guide](Performer-Guide)** — the active version of this experience
- **[Author's Guide](Author-Guide)** — building blockings worth walking
- **[Multi-Devices](Multiple-Devices)** — joining a live director's session
