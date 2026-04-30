# Quick Start

The five-minute version of "what happens when you open Understudy." We'll go from a fresh install to a working three-mark blocking, with one performer hitting marks and firing cues.

## What you'll need

- An **iPhone** running iOS 17 or later (any model from the iPhone 12 onward works great).
- Optional but ideal: a second iPhone, or an Apple Vision Pro for the director side.
- About 2 metres of clear floor in front of you.
- The app, [installed from TestFlight](https://testflight.apple.com/) once we ship a public build — for now, build from source.

You do **not** need a script handy, headphones, or any QLab setup. Ten plays come bundled.

---

## 1. First launch — pick a role

When you launch on iPhone for the first time, you'll see the role picker:

> **What brings you to the stage?**
> 🎤 Perform — Walk the blocking. See cues as you arrive.
> ✏️ Author — Build the blocking. Drop marks where you stand.
> 🎟️ Audience — Take the tour. The show finds you.

For this tutorial, pick **Author**. (You can switch later from Settings.)

The next screen will ask permission to use the camera. Allow it. The live camera feed appears behind a soft dark gradient — you're now standing in your living room with theatrical lighting.

If this is your first time in Author mode, a welcome card walks you through three ideas in 20 seconds. Read it, dismiss it.

---

## 2. Drop three marks

Point your phone at the floor. Wherever you tap on screen, a glowing cyan disc appears — that's a **mark**, a blocking position.

Walk a couple of steps and tap again. Walk again, tap again. You should now have three marks roughly in a triangle on your floor.

> **What just happened:** Each tap raycast through the camera into the real world and dropped a mark at the closest horizontal surface. Marks have a sequence number (1, 2, 3) and a 0.6 m radius — close enough to the centre and you've "arrived."

Don't worry if the marks aren't perfectly placed. You can drag them in the editor, or just drop more.

---

## 3. Add a line to the first mark

Tap the **first mark** (the one labelled "Mark 1"). The mark editor sheet slides up.

You'll see sections for:
- **Mark** — name, radius, position.
- **Lines** — the dialogue this mark fires.
- **Sound, Light, Beat** — non-dialogue cues.
- **All Cues** — the running order, with a ▷ preview button on each.

In the Lines section, tap the purple **Pick from script…** button.

The Script Browser opens with ten plays bundled — Hamlet, Macbeth, Three Sisters, Salomé, Ghosts, the rest. Pick **Hamlet**, then in the scene menu pick **Act I, Scene I**.

Tap any line — say *"Who's there?"* — and a green checkmark appears. That line is now attached to your mark.

Tap **Save** to close the editor.

---

## 4. Switch to Perform and walk to your mark

Tap the gear icon → **Settings → Mode** → **Perform**. Tap Done.

The screen reorganises itself. You're now looking at the live AR camera feed with:
- A guidance ring in the centre that shrinks as you approach the next mark.
- Text at the bottom showing distance: *"1.4 m to Mark 1"*.

Walk towards Mark 1.

When you cross into the disc, three things happen at once:
1. **Haptic pulse.** Your phone buzzes once.
2. **Light cue.** The screen flashes (no light cue authored, so this is muted, but try adding a `.light` cue to see it).
3. **Line displays.** "Who's there?" appears in big serif type at the top of the screen.

You just authored a one-line blocking and walked it. That's the core loop.

---

## 5. Drop a whole scene

The fastest way to feel Understudy's range: switch back to Author mode, tap any mark to open it, hit **Pick from script…**, and at the top of any scene tap **Drop scene**.

Understudy auto-lays out a zig-zag path of marks — one beat per speaker turn, max 4 lines per beat — with every line pre-populated. A 20-beat scene becomes a walkable blocking in under a second.

Switch to Perform, walk the path, and the show plays itself.

---

## Where to next

- **Director's Guide** — running rehearsal in Vision Pro with multiple performers. → [Director-Guide](Director-Guide)
- **Author's Guide** — finer control over cue editing and the script library. → [Author-Guide](Author-Guide)
- **Camera & Film Mode** — same app, lens specs and viewfinder for film pre-viz. → [Camera-and-Film-Mode](Camera-and-Film-Mode)
- **Connecting Multiple Devices** — if you have two iPhones, or want to bring an Android in. → [Multiple-Devices](Multiple-Devices)
- **Troubleshooting** — when something doesn't work. → [Troubleshooting](Troubleshooting)

---

> **Tip:** Every mode has its own teleprompter button (📜 / quote icon at the top). Open it for a karaoke-style scrolling script that follows the performer's voice or auto-scrolls at theatrical pace. See [Performer-Guide § Teleprompter](Performer-Guide#teleprompter).
