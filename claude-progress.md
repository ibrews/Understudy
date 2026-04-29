# Understudy — Overnight Review (2026-04-29)

Branch: `overnight-review` from `main` at b0bfdf5 (v0.29).

## Goal

User reports: visionOS shows just a "black floating window" — never enters immersive/MR mode. Many buttons appear non-functional. Wants: bug fixes + UX polish for non-technical theater/film artists, sim-tested user journeys, GitHub Wiki, TestFlight ship.

## Master bug list (from full code audit)

### CRITICAL — visionOS "black floating window"

1. **No auto-open of ImmersiveSpace.** `UnderstudyApp.swift:85` declares `ImmersiveSpace(id: "Stage")` but only a manual toggle in `DirectorControlPanel:352` opens it. v0.29 made the toggle more visible but it's still opt-in. New users open the app, see the dim DirectorControlPanel window, never tap MR, never see anything happen. → **Auto-open on first launch**.
2. **Invisible floor plane.** `DirectorImmersiveView:64` plane is alpha 0.0001 (tap-detection only). When the user does enter MR, there's no visible ground reference. → **Add a visible translucent stage floor + center marker.**
3. **Empty stage = empty space.** No empty-state guidance when MR is open with no marks. → **Floating hint card "Tap the floor to drop your first mark" when marks.isEmpty.**
4. **"Mixed Reality" is jargon for theater artists.** → **"Open Stage" / "Close Stage".**
5. **Even with marks, the stage is dim.** UnlitMaterial on cyan discs at 0.35 alpha is hard to see in mixed-reality bright passthrough. → **Brighter rim + slight pulse so they read as theatrical "spike marks".**

### HIGH — iOS dead/missing buttons + feedback

6. **MarksOverview is read-only.** `PerformerView:734` — list is just text, no action. → **Tapping a mark previews its cues + flashes its disc**, useful in sim where you can't physically walk.
7. **No recording confirmation.** `PerformerView:268` — record button toggles `store.isRecording` but no visible state change beyond the icon. → **Add "REC" badge with elapsed time while recording, "Reference walk saved (Xs)" toast on stop.**
8. **Missing accessibility labels.** Settings, marks-list, record buttons in PerformerView/AuthorView/AudienceView. → **Add `accessibilityLabel`** to every icon-only button.
9. **AuthorView hint card hidden by default Hamlet demo.** `AuthorView:263` `.opacity(store.blocking.marks.isEmpty ? 1 : 0)` — but the bundled demo has 5 marks, so new users never see the hint. → **Always show a thin contextual hint at the top, swap copy by mark count.**
10. **AudienceView Begin button is purely a UI gate in sim.** Without AR pose, no way to walk through marks for testing. → **Add a subtle "Step" affordance to advance through marks for sim/no-AR walkthrough.**
11. **No way to start a fresh blocking.** Title stays "Hamlet (Opening)" forever. Clear button only zeros marks. → **"New Blocking…" action in Settings + Director panel.**
12. **Onboarding step 3 is wrong.** Author onboarding tells users to tap a "⊕ button" but the actual UI is tap-to-floor. → **Rewrite Author onboarding copy to match reality.**
13. **Audience onboarding mentions "room code" as the way to join,** but the room code is an Apple-platform-only Multipeer rendezvous detail — for a single-device audience, irrelevant. → **Rewrite audience onboarding to match the actual self-paced UX.**

### MEDIUM — UX clarity

14. **DirectorControlPanel is dense and intimidating.** Eight strips stacked vertically, no hierarchy. Theater directors aren't going to know which knob to turn first. → **Add a "Quick Start" section at top with 3 obvious actions: Enter Stage / Drop Demo / Open Teleprompter.**
15. **Settings transport switch immediately tears down + rebuilds.** Bad if user is mid-rehearsal and accidentally taps. → **Add confirmation when peers > 0.** (Lower priority — leave for follow-up)
16. **Peer count opaque.** "X peers" doesn't say who/what platform. → **Tap to see peer list with names + platforms.**

### LOW / DELIGHT

17. **Add a "Simulate walk" button** to Director panel — runs through every mark in sequence with a 2s dwell, firing cues. Lets a director preview their show without performers.
18. **Add audience scrubbing.** Tap any segment of the progress bar to jump to that mark — useful for revisiting a beat.
19. **Add a soft theatrical ambient sound** when entering immersive (one-shot bell or curtain swell). Optional, can be disabled.
20. **Add a "Save to Files…" prompt the first time a blocking diverges from the demo,** so the user's first session isn't lost on relaunch (autosave catches this, but a conscious save moment would help).

## Plan

Order of operations:
1. Verify baseline iOS + visionOS build green (in progress)
2. Fix CRITICAL bugs 1–5 (visionOS UX overhaul)
3. Fix HIGH bugs 6–13 (iOS dead buttons + feedback)
4. UX polish 14, 16
5. Delight 17 (simulate walk) + 18 (audience scrub) — most impactful, smallest cost
6. Bump to v0.30 with version visible on launch
7. Click-test in iOS sim + visionOS sim
8. Verify Mission Control still works
9. Author the GitHub Wiki
10. TestFlight ship + iPhone install
11. Final commit + summary

## Failed approaches

(none yet)

## Notes

- visionOS TestFlight has never been pushed from this fleet per `REVIEW_NEEDED.md`. KB has UE5-context guidance at `~/knowledge/departments/engineering/ue5-ios-testflight-pipeline.md` but it's UE5-specific. Will use `scripts/ship-testflight.sh --platform visionos` and document any record-level rejection if it hits.
- iPhone 17 sim (OS 26.2) on this machine; Apple Vision Pro sim 26.4.1.
