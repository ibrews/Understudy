# DMX Lighting (sACN)

Understudy can drive real lighting fixtures directly. When a `.light` cue fires on a mark, the same data that flashes the screen also goes out as **sACN (E1.31)** packets to your DMX network — your fixtures wash the room while the performer hits their cue.

This page assumes you've used DMX before. If you haven't, the short version is: DMX is the protocol that tells stage lights what to do. sACN is a way to send DMX over Ethernet so you don't have to run XLR cables to every fixture.

---

## What works

- iOS + visionOS only at the moment (Android is on the roadmap)
- sACN (E1.31-2018), multicast or unicast
- 4 RGBW + dim fixtures by default — fully customisable in code
- 7 colour presets: warm, cool, red, blue, green, amber, blackout
- Universe 1 – 63999

---

## Quick setup

On the iPhone (the device that should drive the lighting rig — usually one device, not all of them):

1. **Settings → DMX Output (sACN)**
2. Toggle **Send DMX to lighting rig** ON
3. Enter universe (default `1`)
4. Pick destination:
   - **Multicast (239.255.x.y)** — works with most modern sACN gear out of the box
   - **Unicast to IP** — if your fixture / gateway prefers a directed packet (enter its LAN IP)
5. Tap **Send test wash (warm @ 80%)** to verify connection

If your rig responds, you're done. The next time a `.light` cue fires anywhere in the show, the DMX fires alongside the screen flash.

---

## The default fixture patch

Out of the box, Understudy assumes:

| Fixture | DMX address | Channels |
| ---- | ---- | ---- |
| Fixture 1 | 1 | R, G, B, W, Dim |
| Fixture 2 | 6 | R, G, B, W, Dim |
| Fixture 3 | 11 | R, G, B, W, Dim |
| Fixture 4 | 16 | R, G, B, W, Dim |

Patch your fixtures to those addresses (or change the patch in `DMXCueMapping.swift`) and you're set.

To customise the patch, edit `Understudy/Shared/Effects/DMXCueMapping.swift`. The default is:

```swift
public static var defaultFixtures: [Fixture] = [
    Fixture(startAddress: 1,  redChannel: 1, greenChannel: 2, blueChannel: 3, whiteChannel: 4, dimmerChannel: 5),
    Fixture(startAddress: 6,  redChannel: 6, greenChannel: 7, blueChannel: 8, whiteChannel: 9, dimmerChannel: 10),
    // ...
]
```

You can swap out the four-fixture patch for your own at runtime by replacing `fx.dmxMapping` — useful if your rig has a different topology and you'd rather load a patch from JSON than recompile.

---

## How the colours map

`.light` cues take a colour name + intensity (0.0 – 1.0). The mapping to RGBW values is in `DMXCueMapping`:

| Colour name | R | G | B | W |
| ---- | ---- | ---- | ---- | ---- |
| `warm` | 255 | 217 | 140 | 200 |
| `cool` | 140 | 217 | 255 | 200 |
| `red` | 255 | 0 | 0 | 0 |
| `blue` | 0 | 0 | 255 | 0 |
| `green` | 0 | 255 | 0 | 0 |
| `amber` | 255 | 191 | 51 | 0 |
| `blackout` | 0 | 0 | 0 | 0 |

Intensity scales the dimmer channel linearly (0 = blackout, 1 = full). RGBW channels are sent at full saturation regardless — if you want intensity to scale R/G/B, edit `DMXCueMapping.frame(for:intensity:)`.

---

## Multicast vs unicast

- **Multicast (default)** — sACN packets go to `239.255.{universe>>8}.{universe&0xFF}`. Most modern sACN gear (ETC Nomad, lighting consoles, sACN-to-DMX gateways) listens on this multicast address by default. If your gear is on the same LAN, this just works.
- **Unicast** — directed UDP to a specific IP. Use this for gateways that don't subscribe to multicast (some older Enttec / ColorKinetics units), or when you're going through a router that doesn't pass multicast.

Unicast is more reliable across complex networks but requires you to know the gateway's IP.

---

## Hardware that works

Tested with:
- **ETC Nomad / Eos** (multicast, universe 1)
- **xLights / QLC+** running on a Mac as a sACN-to-USB-DMX bridge
- **Enttec ODE Mk2** sACN gateway (unicast, configured via Enttec's web UI)
- **Onyx** (multicast)

Untested but should work with anything that announces sACN E1.31-2018 compatibility.

---

## Pairing with QLab

DMX and OSC are independent — you can run both at once. Typical setup:

- **OSC → QLab**: design cues, sound, video → QLab's existing cue stack
- **DMX → fixtures**: the actual light wash → Understudy → fixtures directly

Or all-DMX:
- **DMX → fixtures**: from Understudy
- **OSC → QLab**: ignored / disabled

Or all-OSC:
- **OSC → QLab**: light cues hit QLab, which talks to fixtures (typical theatre setup)
- **DMX**: disabled

Pick whichever matches the show you already know how to drive.

---

## Troubleshooting

**Test wash sent, no fixture response.** Check the universe matches the fixture's listening universe. Many fixtures default to universe 1; some to universe 0 (which Understudy doesn't currently support — universe 1 is minimum). If you're using multicast, confirm fixtures and the iOS device are on the same Wi-Fi network with multicast not blocked (corporate / hotel networks often block this).

**Fixtures flicker mid-cue.** sACN expects packet rate ≈ 44 Hz. Understudy sends a single packet per cue, not a continuous stream. If your fixture is configured for "instant on" with a long DMX timeout, you might see flicker. Increase the fixture's DMX-loss timeout, or implement a continuous loop in `DMXOutput.swift` (planned for v0.32).

**Wrong colour.** Check the patch — Understudy assumes R-G-B-W-Dim order at addresses 1, 6, 11, 16. If your fixture uses Dim-R-G-B-W, the mapping in `DMXCueMapping.swift` will be off and you'll see e.g. red when blue was called. Edit the channel offsets.

**Fixtures black out unexpectedly.** Understudy doesn't currently send a "no light" frame between cues — DMX hold values until the next cue. If a previous cue was at full and the next one is too dim to read, that's by design. To force black between cues, add an explicit `.light(blackout)` cue.

---

## Where to next

- **[QLab and OSC](QLab-and-OSC)** — the OSC bridge, complementary to DMX.
- **[Author's Guide § Light cues](Author-Guide#light)** — authoring `.light` cues that drive both the screen flash and DMX.
