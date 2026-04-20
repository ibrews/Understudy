# Understudy Quickstart

Running the full multiplayer stack — Vision Pro director, iPhone performer, Android performer — on a single LAN.

## The three parts

| Part        | Where           | When you need it                                             |
|-------------|-----------------|--------------------------------------------------------------|
| Apple app   | `Understudy/`   | Always — ships for iOS and visionOS from one Xcode target    |
| Android app | `android/`      | Whenever an Android phone is joining the rehearsal           |
| Relay       | `relay/`        | Only when Android is joining (or you want a remote session)  |

Apple-only sessions can skip the relay entirely — MultipeerConnectivity auto-discovers over Bonjour.

## Pure Apple session (fastest path)

1. Open `Understudy.xcodeproj` in Xcode.
2. Run the `Understudy` scheme to a visionOS simulator (or device). Turn **Stage On** in the director panel.
3. Run the same scheme to an iPhone on the same Wi-Fi.
4. Both devices default to **Transport: Multipeer** and **Room: rehearsal**. They find each other automatically.

## Cross-platform (iPhone + AVP + Android)

1. **Start the relay** on any Mac/Linux box on the LAN:
   ```bash
   cd relay
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   python3 server.py
   # Understudy relay starting on ws://0.0.0.0:8765
   ```
   Note the host's LAN IP — say `192.168.1.42`.

2. **Apple side:** in the director panel (or iPhone Settings sheet), switch **Transport** to **WebSocket relay** and set the URL to `ws://192.168.1.42:8765`. Same room code across all devices.

3. **Android side:** open the app, tap the gear, enter `ws://192.168.1.42:8765` and the same room code. Grant camera permission (needed for ARCore world tracking).

## What to try first

1. On the director, **Stage On** and tap the floor in the immersive space a few times to place marks.
2. Walk to any phone. The teleprompter shows "Find your mark" with a distance readout.
3. Walk onto a mark. The phone pulses; the director sees a ghost-avatar arrive on that mark.
4. On the director, open a mark, add a line cue (e.g. "Something is rotten in the state of Denmark"). Next time anyone steps on that mark, the line appears on their phone.
5. Hit the phone's record button, walk a path through all the marks, stop. Scrub the playback slider on the director panel — a ghost replays your walk across everyone's view.

## Troubleshooting

| Symptom                                  | Fix                                                                 |
|------------------------------------------|---------------------------------------------------------------------|
| Peers count stays 0 on Multipeer         | Same Wi-Fi? iOS "Local Network" permission granted?                  |
| "Tracking limited" on phone              | Walk slowly in a well-lit space for 5-10 seconds                     |
| WebSocket won't connect                  | `lsof -i :8765` on relay host — something else on that port?        |
| Android can't find ARCore                | Play Store → ARCore ("Google Play Services for AR") → install        |
