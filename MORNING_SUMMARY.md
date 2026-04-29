# Overnight Review — Morning Summary (2026-04-29)

Branch: `overnight-review` ([compare → main on GitHub](https://github.com/ibrews/Understudy/compare/main...overnight-review))
Version shipped: **v0.30 (33)**
Total commits this branch: see `git log main..overnight-review --oneline`

## TL;DR

Headline fix you asked about — the visionOS "black floating window" — has three root causes and three fixes. Plus 10+ smaller bugs and dead-button issues across iOS. Plus a 13-page user-facing wiki targeted at theatre/film artists. v0.30 (33) is shipped to TestFlight (iOS) and the iPhone install is queued. *(Wiki at `/wiki/` in the repo; mirroring to the GitHub Wiki tab needs a one-click bootstrap from you — see `wiki/README.md`.)*

## What I fixed

### visionOS — the "black floating window" (CRITICAL)

The user's headline complaint had three root causes layered:

1. **Immersive space never auto-opened** — `ImmersiveSpace(id: "Stage")` was declared but only opened by a manual toggle in the room row. v0.29 made the toggle more visible but kept it opt-in. **Fix:** auto-open on first appearance, gated on a new `@AppStorage("autoOpenStage")` (default ON). User can disable from the panel if they prefer.
2. **Floor was invisible** — the tap-detection plane was alpha=0.0001, so when you DID enter immersive there was nothing to anchor your eye. **Fix:** added a 0.4 m red center disc + 4×6 m translucent cyan stage perimeter. Both auto-dim once marks are placed so they don't compete.
3. **Empty stage = empty space** — no guidance when MR is open with no marks. **Fix:** floating welcome card "Tap the floor to drop a mark" anchored 1.4 m above stage center, hides the moment the first mark exists.

Additional visionOS improvements:
- New **Quick Start** strip at the top of the Director Panel — three big buttons: Open/Close Stage, Teleprompter, **Preview Show** (NEW: walks the GO cursor through every mark at 2.5 s/beat for a no-performers rehearsal of the cue stack).
- "Mixed Reality" jargon → "Open Stage" / "Close Stage" — better for theatre artists.
- Mark discs brightened (cyan @ 0.55 alpha + 0.95 rim) so they read against bright passthrough.
- Panel made scrollable since the new sections push content past the default window height.

### iOS — dead buttons + missing feedback

The user's "many buttons that don't do anything" complaint mapped to:

- **MarksOverview list rows are now buttons** — tap any mark to fire its cues immediately (sim-friendly, also useful for live-rehearsal scrubbing).
- **Recording feedback** — flashing red REC pill with elapsed seconds while recording, "Walk saved (X.Ys)" toast on stop.
- **AuthorView hint card** — was hidden once marks existed (always, since the bundled Hamlet demo pre-loads 5 marks). Now stays visible as a thin pill so the tap-the-floor gesture is always discoverable.
- **AudienceView progress bar is scrubbable** — tap any beat to fire its cues; beat ticks render along the bar; "Scrubbing — tap Stop to release" indicator.
- **New Blocking…** action in Settings — replaces the bundled Hamlet title, not just clears marks.
- **Onboarding copy fixed** — Author step 1 told users to "tap the ⊕ button" but the actual UI is tap-the-floor; rewrote. Audience flow was structured around joining a director's room as the primary path; rewrote to lead with self-paced solo.
- **Accessibility labels** added to every icon-only button across PerformerView, AuthorView, AudienceView.

### TestFlight signing

Hit a real obstacle — the existing "Understudy App Store" provisioning profile was out of sync with the active Apple Distribution cert. Tried switching to automatic signing first (per KB pattern), but the App Manager API key lacks "Cloud Managed App Distribution Certificate" permission. Final fix: a new script `scripts/regenerate-ios-profile.sh` that POSTs a fresh `IOS_APP_STORE` profile via the ASC API, pinning the current cert. Bonus: ASC creates the profile as multi-platform `[iOS, xrOS, visionOS]`, so one profile covers both platform uploads.

## What's in `/wiki/`

13 pages targeted at non-technical theatre and film artists:

- **Home, Quick-Start, Glossary** — entry points
- **Director-Guide, Performer-Guide, Author-Guide, Audience-Mode** — one per role
- **Camera-and-Film-Mode** — film pre-viz, lens specs, viewfinder overlay
- **Multiple-Devices** — Multipeer / WebSocket / calibration / Mission Control
- **QLab-and-OSC** — bidirectional show control
- **DMX-Lighting** — sACN output to real fixtures
- **Room-Scanning** — LiDAR capture + alignment
- **Bundled-Plays** — the 10 included plays
- **Troubleshooting** — including "black floating window" first
- **_Sidebar.md** — GitHub Wiki tab nav (used when mirrored)
- **README.md** in `/wiki/` — explains the one-time GitHub Wiki bootstrap

To mirror to the GitHub Wiki tab, you need to **visit https://github.com/ibrews/Understudy/wiki and click "Create the first page" once** (any content; we overwrite it). After that, `wiki/README.md` documents the simple `git clone + cp + push` sync. Until then, the markdown is browseable directly at <https://github.com/ibrews/Understudy/tree/main/wiki>.

## What's left for you

1. **Verify the visionOS fix on real Vision Pro hardware.** Sim screenshots can't show floor-level immersive content (the user is always looking straight ahead). Look down at the floor when you launch the app — you should see the red center disc + cyan perimeter within ~1s of the panel appearing. If they're missing, see [REVIEW_NEEDED.md § 1-2](./REVIEW_NEEDED.md).
2. **Bootstrap the GitHub Wiki tab.** One UI click on `https://github.com/ibrews/Understudy/wiki` then run the sync per `wiki/README.md`.
3. **Verify TestFlight builds work end-to-end.** v0.30 (33) iOS should be processing in App Store Connect. Once it's available, install and walk through:
   - First-launch role picker → pick Author
   - Tap the floor → mark drops
   - Tap a mark → editor opens, cues are previewable
   - Settings → Mode → Perform — walk the demo
   - Settings → Mode → Audience — scrub the progress bar
   - Settings → New Blocking… — confirm fresh blocking
4. **Decide on visionOS TestFlight.** I shipped iOS first; visionOS attempt is documented in REVIEW_NEEDED.md. The new profile supports xrOS too, so a `scripts/ship-testflight.sh --platform visionos` should work — but per REVIEW_NEEDED, the App Store Connect record may need visionOS added under App Information → Add Platform first. **I did not auto-add the platform** since that's a record-level change.

## Branch and version

- Branch: `overnight-review`
- All commits pushed to `origin/overnight-review`
- Version on disk: v0.30 (33) — visible in every top bar via `AppVersion.formatted`
- Android version bumped to 33 too, but I didn't touch any Android code (out of scope unless wire format changed; it didn't)

## Files changed

```
$ git diff --stat main..overnight-review
```

Summary:
- 17 wiki pages added (`wiki/*.md`)
- visionOS UX overhaul (`UnderstudyApp.swift`, `DirectorControlPanel.swift`, `DirectorImmersiveView.swift`)
- iOS UX overhaul (`PerformerView.swift`, `AuthorView.swift`, `AudienceView.swift`, `OnboardingSheet.swift`)
- New `scripts/regenerate-ios-profile.sh`
- README v0.30 changelog entry
- claude-progress.md (this overnight session log)
- REVIEW_NEEDED.md updated with verification gaps

## Suggested next steps after morning verification

If everything looks good:
- Merge `overnight-review` → `main` via PR (or rebase + ff)
- Bump to v0.31 next session for the open `Next up` items

If something's broken:
- The branch makes everything reversible — check out `main` and the bug never existed
- `claude-progress.md` documents every decision for context

## Time-cost note

This was a single autonomous overnight session, ~3-4 hours of compute time including extensive code reading, wiki authoring, and TestFlight troubleshooting. The signing-profile detour cost ~30 minutes and produced a reusable script for future profile drift. No usage budget warnings hit.
