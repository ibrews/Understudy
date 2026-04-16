# OSC Bridge — Understudy → QLab, TouchDesigner, Max, Isadora, etc.

When OSC is enabled (Settings → OSC Bridge on iPhone, or OSC → QLab row on visionOS), every cue that fires on the local device is also emitted as an OSC 1.0 UDP message to a configured host + port.

Standard QLab OSC port is **53000**.

## Messages

| Address                   | Arguments                         | Fires on                              |
|---------------------------|-----------------------------------|---------------------------------------|
| `/understudy/mark/enter`  | `<markName:s> <seqIndex:i>`       | First cue of a mark after entry       |
| `/understudy/cue/line`    | `<character:s> <text:s>`          | A `.line` cue                         |
| `/understudy/cue/sfx`     | `<name:s>`                        | A `.sfx` cue (bell, thunder, etc.)    |
| `/understudy/cue/light`   | `<color:s> <intensity:f>`         | A `.light` cue                        |
| `/understudy/cue/wait`    | `<seconds:f>`                     | A `.wait` cue                         |
| `/understudy/cue/note`    | `<text:s>`                        | A `.note` cue (director-only)         |
| `/understudy/test`        | `<payload:s>`                     | The "Send test message" button        |

Type tags follow OSC 1.0: `s` = null-terminated ASCII, `i` = 32-bit big-endian int, `f` = 32-bit big-endian IEEE float. No bundles, no time tags, no TCP.

## Example: QLab

1. In QLab's Preferences → OSC Controls, enable **OSC receive**.
2. On the Understudy device that hosts the director (or any performer), set the OSC destination to your QLab machine's LAN IP and port **53000**.
3. In QLab, use *Network Triggers* on each cue:
   - Trigger type: **OSC**
   - Match: `/understudy/cue/sfx thunder` → go your Thunder sound cue
   - Or wildcard: `/understudy/mark/enter *` with scripting to look up the mark name

## Example: TouchDesigner

Use an `oscin1` DAT with port 53000, parse the address + values, and drive visual parameters directly. `/understudy/cue/light amber 0.8` maps cleanly to a light rig color.

## Example: Max / Max for Live

```
[udpreceive 53000]
  |
[route /understudy/cue/sfx /understudy/cue/light]
```

## Inbound — Stage Manager GO from QLab → Understudy

Understudy also *listens* for OSC. Any device can enable the inbound receiver from Settings → "Stage Manager (inbound)" (iPhone) or the director panel's OSC sheet (visionOS). Default listen port is **53001**.

| Address                   | Arguments    | Effect                                       |
|---------------------------|--------------|----------------------------------------------|
| `/understudy/go`          | *(none)*     | Advance cue cursor by 1; fire next mark's cues |
| `/understudy/next`        | *(none)*     | Alias for `/go`                              |
| `/understudy/back`        | *(none)*     | Step cue cursor back by 1; re-fire its cues  |
| `/understudy/mark`        | `<seq:int>`  | Jump cursor to mark with that sequence index |
| `/understudy/reset`       | *(none)*     | Reset cursor to before first mark            |

Internally, `/go` advances a cursor that's independent of performer movement. Each GO enqueues every cue on the next mark (in its defined order) onto the shared `cueQueue` — identical path to a real walk-on entry — so the usual system fires: teleprompter shows the line, SFX plays, light flashes, and the outbound OSC stream mirrors it right back out. A second Understudy / QLab listening on the outbound stream sees everything. Round-trip complete.

### QLab example

In QLab → *Toolbox* → Network cue:
```
Type:         Network
Destination:  <Understudy device IP>:53001
Custom OSC:   /understudy/go
```

Bind that cue to a hotkey (typically the space bar). Now the SM is running the show: space advances the stack, Understudy's teleprompter + Understudy's own outbound OSC triggers QLab's show cues in lock-step.

### Director-panel manual GO

On visionOS, the director panel has a GO button next to the OSC row (keyboard shortcut: Return). Same semantics as an inbound `/understudy/go`. For when there's no QLab in the room and the director is stage-managing themselves.

## Notes

- OSC is fire-and-forget UDP — dropped packets are not retried.
- Outbound messages are sent from whichever device is firing the cue. In a multi-performer session, every phone may send its own copy when it crosses a mark. If you want a single authoritative OSC emitter, enable outbound OSC only on the director (visionOS) or one designated phone.
- Encoder is in `Understudy/Shared/Effects/OSCBridge.swift`, receiver in `OSCReceiver.swift`. ~200 lines combined including UDP plumbing and a minimal OSC 1.0 parser. Easy to extend.
