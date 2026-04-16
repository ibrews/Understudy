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

## Notes

- OSC is fire-and-forget UDP — dropped packets are not retried.
- Messages are sent from whichever device is firing the cue. In a multi-performer session, every phone may send its own copy when it crosses a mark. If you want a single authoritative OSC emitter, enable OSC only on the director (visionOS) or one designated phone.
- Encoder is in `Understudy/Shared/Effects/OSCBridge.swift` — ~80 lines including the UDP plumbing. Easy to extend.
