# Understudy — Vision Pro Overhaul + iOS Overhaul (2026-06-04)

**Session:** 5899ad5e · **Branch:** `vision-pro-overhaul` (off main) · turn-guard raised to 8000.
**Plan of record:** KB `projects/understudy/vp-overhaul-plan.md` (banked this session).

> ⚠️ Survived a mid-session reboot. /tmp is wiped on reboot → re-apply turn-guard
> override `echo 8000 > /tmp/tg-5899ad5e-418d-4550-bee1-d01754fb83f4.max` and
> rebuild (derived data gone). All git commits + source edits persist on disk.

## Device UDIDs (for sim verification)
- **Apple Vision Pro** (visionOS 26.5): `A540B3B5-CB1D-477D-A3B9-A6D41598B704`
- **iPhone 17** (iOS 26): `974E8854-BFD9-4A36-A653-ED2142709C79`
- iPhone 17 Pro: `91FCB7A8-414C-47B9-A5D9-98BA261BBA62`

## Plan & Status
- [x] **Step 0** — KB banked (`0c638f38a`); Monitoring deletion (`e14bfa7`); build-verify main visionOS+iOS; push main; prune 10 worktrees+branches.
- [x] **Step 1** — AVP immersive fixes + beyond. Commits on branch:
  - [x] `b5ae9e8` A4 (sync reads in update:), A1 ImmersiveSceneCoordinator, A2/A3 serialized opens + recoverable banner, A5 drop -1.0 Y. visionOS+iOS BUILD SUCCEEDED.
  - [x] `4abc5c3` skybox (full-immersion env), Mixed↔Full toggle, real/virtual hands toggles. visionOS BUILD SUCCEEDED.
  - [ ] runtime sim smoke-test (launch, auto-open, no crash) — in progress
- [ ] **Step 2** — first-run onboarding (directorIntroStep @AppStorage + coach-cards; fix seed/empty contradiction at UnderstudyApp:41 ↔ DirectorImmersiveView empty-hint)
- [ ] **Step 3** — iOS overhaul (ux-flow-auditor + axiom-swiftui), states, modernize, README + wiki
- [ ] **Before merge to main:** bump version (project rule — v0.36→v0.37, show in UI via AppVersion.formatted), full build-verify both platforms, merge.

## Key file references (current)
- `Understudy/VisionOS/ImmersiveSceneCoordinator.swift` (NEW) — app-scoped @Observable @MainActor; Phase, open/close/toggle, systemDidPresent/Dismiss, isFullImmersion, showRealHands, showVirtualHands.
- `UnderstudyApp.swift` — injects coordinator; ImmersiveSpace .onAppear/.onDisappear → systemDidPresent/Dismiss; .immersionStyle(selection: binding, in: .mixed, .full); .upperLimbVisibility.
- `DirectorControlPanel.swift` — @Environment coordinator; button off coordinator.isOpen/.isBusy; .task auto-open; immersionControls strip; immersiveErrorBanner.
- `DirectorImmersiveView.swift` — update: reads synchronous (A4); skybox + virtualHand anchors in make:; syncImmersionEnvironment/syncVirtualHands; stageRoot at [0,0,-0.5].

## Failed Approaches (preserve — do not retry blind)
- **Automatic signing for export** fails: App Manager API key lacks Cloud Managed App Distribution Certificate permission. Use manual signing.
- **Duplicate provisioning profiles**: two "Understudy App Store" profiles shadowed each other; delete stale, rename new to UUID-canonical filename.
- **`TextureResource(image:options:)`** requires `if #available(visionOS 2.0, *)` (deployment target is visionOS 1.0) — else "only available in visionOS 2.0 or newer".
- **`Self.stageID` in a default arg** → "covariant 'Self' cannot be referenced from a default argument expression"; use the explicit type name.
- **Naming a method param `open`/`dismiss`** shadows the same-named method → call resolves to the method, not the action. Use `action`/`openAction`.

## iOS bug audit (from 2026-04-29 overnight review — re-verify vs current source for Step 3)
6 MarksOverview read-only (PerformerView) → tap to preview cues + flash disc.
7 No recording confirmation (PerformerView) → REC badge + elapsed + saved toast.
8 Missing accessibility labels on icon-only buttons (Performer/Author/Audience).
9 AuthorView hint hidden when demo has marks → always show thin contextual hint.
10 AudienceView Begin is sim UI gate w/o AR pose → "Step" affordance for no-AR walkthrough.
11 No "New Blocking…" reset (title stuck "Hamlet (Opening)") → Settings + Director panel.
12 Author onboarding step 3 says "⊕ button" but UI is tap-to-floor → rewrite copy.
13 Audience onboarding mentions room-code join (irrelevant single-device) → rewrite.
14 DirectorControlPanel dense → "Quick Start" (already has one; verify).
16 Peer count opaque → tap to see peer names + platforms.

## Notes
- Secondary megasession jobs (KB health-check wirptib8r, fleet eval wkzyfoucs, jobs 2/6/7/8) → SEPARATE session; do not drain this call budget.
