# Understudy — Vision Pro Overhaul + iOS Overhaul (2026-06-04) — COMPLETE

**Session:** 5899ad5e · merged to `main` as `68171bc` · **v0.37 (40)**.
**Plan of record:** KB `projects/understudy/vp-overhaul-plan.md`.

## Device UDIDs (sim verification)
- Apple Vision Pro (visionOS 26.5): `A540B3B5-CB1D-477D-A3B9-A6D41598B704`
- iPhone 17 (iOS 26): `974E8854-BFD9-4A36-A653-ED2142709C79`
- iPhone 17 Pro: `91FCB7A8-414C-47B9-A5D9-98BA261BBA62`

## Status — ALL STEPS DONE, merged to main
- [x] **Step 0** — KB bank (`0c638f38a`); Monitoring deletion; build-verify; push main `e14bfa7`; prune 10 worktrees+branches.
- [x] **Step 1** — AVP immersive: `b5ae9e8` (A4 sync reads, A1 ImmersiveSceneCoordinator, A2/A3 serialized opens + banner, A5 floor) + `4abc5c3` (skybox, Mixed↔Full, real/virtual hands). Sim-verified: single clean auto-open, renders at floor, no crash.
- [x] **Step 2** — `9218365` first-run DirectorOnboardingView (5-step), re-reachable Tutorial button, seed/empty resolved. Sim-verified sheet presents.
- [x] **Step 3** — `177dd37` iOS overhaul (ux-flow-auditor: 3 critical + 6 high fixed): connection pill + join-room, error states (voice-denied, scan-needs-AR, discard toast), empty states, a11y labels, GuidedTour backfill; README Things-to-Try + Xcode ver + attribution(→Alex Coulombe). `14ff8fc` wiki (Director + Performer guides). Sim-verified: Perform view + connection pill + v0.37 visible, no crash.
- [x] Version bumped 0.36→0.37 (39→40), visible in-app via AppVersion.
- [x] Both platforms BUILD SUCCEEDED; merged `vision-pro-overhaul` → main (`68171bc`), pushed origin/main + origin/vision-pro-overhaul.
- [x] **Polish pass (`4d8644c`):** PerformerView tap-to-restart-tracking (+ `PerformerARHost.restartTracking()`), ScriptBrowser loading indicator, removed irrelevant audience calibration button. iOS build clean; relaunch-verified (no crash).

## Backlog pass (2026-06-04)
- [x] **AuthorView dead state wired (`9373c7a`):** `showingDemoLauncher`/`showingMetrics` now drive a top-bar overflow menu (Stage Map / Show Stats / Run Demo) — iOS Author gets the planning tools the Director panel has. Dead code resolved by using it.
- [x] **First test target (`0fc93e9`):** UnderstudyTests (Swift Testing, hosted via TEST_HOST) + shared Understudy scheme. 6 tests guard ImmersiveSceneCoordinator (incl. the A1 systemDidDismiss regression). All pass: `xcodebuild test -scheme Understudy -destination 'platform=visionOS Simulator,id=A540B3B5…'`.

- [x] **Photographic studio HDRI skybox (`680315f`):** bundled CC0 Poly Haven `studio_small_07` (1K EXR, 1.4MB) as the full-immersion backdrop (ImageIO → TextureResource, gradient fallback). New SkyboxAssetTests verifies bundling + ImageIO EXR decode on visionOS (8 tests total now pass). Sim-verified the dark-studio backdrop renders in full immersion. CC0 credited in README.
  - **Note:** scoped as a *visible backdrop*, NOT IBL — all content is UnlitMaterial by design, so true image-based lighting has no visible effect. `EnvironmentResource(equirectangular:)` is the verified path if content ever moves to PBR.

### Still genuinely deferred (need device, not code)
- **A5 auto floor-plane anchoring** — `AnchorEntity(.plane(.floor))` doesn't resolve in the visionOS Simulator (would hide the stage there). Core A5 (underground) already fixed. A manual "recenter" needs an ARKitSession/WorldTrackingProvider + a world-sensing entitlement (device-only) — a real change, not polish.
- **True IBL on lit content** — would require converting the avatars/stage from their intentional flat UnlitMaterial look to PBR (a visual-design change, not a bug). The HDRI is bundled and ready if that's ever wanted.

## Note — shared simulator
iPhone 17 sim (`974E8854…`) is shared with a concurrent megasession running `com.ibrews.crystalcaper` (a SpriteKit game). It can grab the sim foreground, so a one-off screenshot may capture the wrong app — re-`simctl launch agilelens.Understudy` to re-foreground. Both apps coexist fine; not an Understudy issue.

## Failed Approaches (preserve)
- Automatic signing for export fails (API key lacks Cloud cert perm) → manual signing.
- Duplicate provisioning profiles shadowed each other → delete stale, UUID-canonical filename.
- `TextureResource(image:options:)` needs `if #available(visionOS 2.0, *)`.
- `Self.stageID` in a default arg fails → use explicit type name.
- Method param named `open`/`dismiss` shadows the method → use `action`.

## Notes
- Secondary megasession jobs (KB health-check wirptib8r, fleet eval wkzyfoucs, jobs 2/6/7/8) → SEPARATE session.
