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

## Deferred / backlog (noted, not done — out of scope or lower ROI)
- ux-flow-auditor MEDIUM/backlog: AuthorView dead `showingDemoLauncher`/`showingMetrics` state vars (pre-existing; left per "don't delete unasked" — flag to Alex); ScriptBrowser loading indicator; AR "restart tracking" tap affordance; audience calibration-button hidden for audience (LOW).
- A5 device refinement: floor-plane AnchorEntity (deferred — unreliable in Simulator); IBL from a bundled .skybox/.exr (current skybox is a generated gradient).

## Failed Approaches (preserve)
- Automatic signing for export fails (API key lacks Cloud cert perm) → manual signing.
- Duplicate provisioning profiles shadowed each other → delete stale, UUID-canonical filename.
- `TextureResource(image:options:)` needs `if #available(visionOS 2.0, *)`.
- `Self.stageID` in a default arg fails → use explicit type name.
- Method param named `open`/`dismiss` shadows the method → use `action`.

## Notes
- Secondary megasession jobs (KB health-check wirptib8r, fleet eval wkzyfoucs, jobs 2/6/7/8) → SEPARATE session.
