# Understudy

**Multiplayer spatial theater — and film pre-viz. A Vision Pro director, iPhones and Android performers, real lights, real lines, real cues. Bring a show into the room before it gets a venue.**

This is the user guide. If you're a developer, the engineering README lives at the [repo root](https://github.com/ibrews/Understudy). If you're a director, performer, scout, or just curious — start here.

---

## What is Understudy?

Understudy turns a real room into a programmable stage.

A **director** wearing Apple Vision Pro places blocking marks on the floor — actual points in 3D space — and attaches lines, sound cues, and light cues to each one.

A **performer** holds an iPhone (or Android) that becomes a smart teleprompter: walk onto a mark, your phone pulses, the next line appears, the sound fires, the "amber" light washes the room.

The director sees every performer as a ghost avatar moving through the same virtual stage, in real time.

When the show is locked in, anyone with a phone can **walk it back** as a self-paced AR audio tour. Site-specific theater becomes shareable. The audience can literally step into the actor's path.

For **film**, the same model serves directors, DPs, and location scouts: drop virtual camera marks with real lens specs (14/24/35/50/85/135 mm), see field-of-view wedges anchored in the room, and use the phone as a viewfinder.

> *"Figma for stage direction."*

---

## Pick your role

Different people use Understudy for different things. The app supports four roles — pick the one that matches what you're trying to do, then jump to its guide.

| You're a... | Open this | Then read |
| ---- | ---- | ---- |
| 🎭 **Theater director** running a rehearsal in a real room with performers on iPhones | Apple Vision Pro | [Director's Guide](Director-Guide) |
| 🎬 **Film director / DP / location scout** previewing camera coverage with a phone | iPhone (Author mode → Camera) | [Camera & Film Mode](Camera-and-Film-Mode) |
| 🎤 **Actor or stage performer** running lines with a smart teleprompter | iPhone (Perform mode) | [Performer's Guide](Performer-Guide) |
| ✏️ **Stage manager / author** building a blocking from scratch | iPhone (Author mode) | [Author's Guide](Author-Guide) |
| 🎟️ **Audience** walking a finished show as an AR tour | iPhone (Audience mode) | [Audience Mode](Audience-Mode) |

If you're working with multiple people on different devices, keep going to **[Connecting Multiple Devices](Multiple-Devices)** after you read your role's guide.

---

## 90 seconds to your first mark

The fastest way to feel what Understudy does:

1. **Open the app on iPhone.** The first screen asks "What brings you to the stage?" — pick **Author**.
2. **Grant camera permission** when prompted. The live camera feed appears behind a soft dark gradient.
3. **Tap the floor** anywhere on screen. A glowing cyan disc appears — that's your first mark.
4. **Tap that mark.** The mark editor opens. Tap **Pick from script…** at the top of the Cues section.
5. **Pick any play.** Try Hamlet → Act I, Scene I. Tap any line — say *"Who's there?"* — and it's now attached to that mark.
6. **Hit Save**, then close out and switch to **Perform mode** in Settings.
7. **Walk towards the mark.** When you get within range, your phone pulses, a light wash flashes, and Bernardo speaks his line.

That's it. You just authored, performed, and rehearsed a one-mark blocking.

For the full multi-device flow, see [Quick Start](Quick-Start) →

---

## What's in this wiki

### For everyone
- **[Quick Start](Quick-Start)** — 90-second tutorial expanded into a 5-minute one
- **[Glossary](Glossary)** — terms used throughout: mark, blocking, cue, calibration, room code

### For the four roles
- **[Director's Guide (visionOS)](Director-Guide)** — what to do in the headset, how to drop marks, run rehearsal, fire cues
- **[Performer's Guide (iPhone)](Performer-Guide)** — phone as smart teleprompter, voice mode, recording walks
- **[Author's Guide (iPhone)](Author-Guide)** — building blockings from scratch, picking lines from the bundled plays, dropping whole scenes
- **[Audience Mode](Audience-Mode)** — site-specific theater as a finished product, scrubbing through the show

### Specialty workflows
- **[Camera & Film Mode](Camera-and-Film-Mode)** — virtual camera marks, lens presets, the phone as a viewfinder
- **[Connecting Multiple Devices](Multiple-Devices)** — Apple → Apple over Bonjour, Android via WebSocket relay
- **[Showrunning with QLab (OSC)](QLab-and-OSC)** — bidirectional cue control for stage managers
- **[DMX Lighting Boards](DMX-Lighting)** — fire real fixtures via sACN
- **[The Bundled Plays](Bundled-Plays)** — what's included and how to use them
- **[Room Scanning (LiDAR)](Room-Scanning)** — capturing a real space and aligning it to your rehearsal room

### When something goes wrong
- **[Troubleshooting](Troubleshooting)** — common issues and fixes

---

## Who built this

Designed and built by [Alex Coulombe](https://alexcoulombe.com) at [Agile Lens](https://agilelens.com), in collaboration with Claude. Iterated in ambitious afternoon and overnight sessions.

For licensing, contributions, or commercial use — see the [main repo](https://github.com/ibrews/Understudy) or [reach out](mailto:info@agilelens.com).
