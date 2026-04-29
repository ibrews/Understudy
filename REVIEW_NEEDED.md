# Review Needed

Things I know the answer to today, but might bite us under new conditions. Clear an item by confirming the behavior on hardware and deleting it.

## v0.30 — Overnight review verification gaps (2026-04-29)

These are changes I made overnight that compiled and launched cleanly in sim, but I couldn't fully verify because the visionOS sim doesn't render immersive content visibly in screenshots and I didn't drive the iOS UI through every state.

1. **visionOS auto-open immersive on first appearance.** UnderstudyApp.swift declares `ImmersiveSpace(id: "Stage")` and DirectorControlPanel's `onAppear` now calls `openImmersiveSpace(id: "Stage")` if `@AppStorage("autoOpenStage") == true`. **I confirmed:** the panel appears in the visionOS sim, the app launches without crashing. **I did NOT confirm:** whether the immersive space actually opens on first launch (sim screenshots show the user's gaze straight ahead, not down at the floor where the immersive content would be). On real Vision Pro hardware, look down at the floor as the panel appears — you should see a red puddle at center + cyan playing-area rectangle within ~1s of the app launching. If you don't, check that `autoOpenStage` is actually true in UserDefaults (it should default true).

2. **visionOS visible floor + perimeter + empty hint.** Added a 0.4 m red center disc, 4×6 m cyan perimeter, and a floating "Tap the floor to drop a mark" attachment that hides when marks exist. Stage perimeter dims to 0.25 opacity once marks are placed. **I did NOT visually confirm these in sim** — same screenshot limitation. Verify on hardware by entering immersive mode with zero marks present (Settings → Blocking → New Blocking…) and looking at the floor.

3. **Preview Show button in Director Panel.** Walks the GO cursor through every actor mark at 2.5s/beat, firing cues. **Tested in code review** — uses the same `fx.goForward()` path as the OSC `/understudy/go` flow, which was already working. **Not exercised in sim** because I'd need to enter immersive and drop marks first. Verify by tapping Preview Show after the bundled Hamlet demo loads — should fire 5 cue batches over ~12 seconds.

4. **iOS audience progress-bar scrub.** Tap or drag the progress bar to fire any beat's cues. **Compiled clean** but not exercised in sim. Verify by switching iPhone to Audience mode, tapping Begin, then tapping the progress bar — each tick should fire its mark's cues.

5. **iOS recording REC pill + saved-walk toast.** TimelineView-driven flashing dot + elapsed seconds badge while recording. Toast on stop. **Not exercised** — the iPhone sim doesn't have AR pose data to record meaningfully. Verify on physical iPhone.

6. **MarksOverview tappable list.** Tap any mark in the marks list (PerformerView) to fire its cues. **Not exercised in sim**. Should fire haptic + cue queue on tap.

7. **TestFlight signing approach changed from manual to automatic.** The previous "Understudy App Store" provisioning profile was out of sync with the active Apple Distribution cert (probably a re-issue; keychain has both old and new certs but the profile pinned the old one). Switched ExportOptions.plist to `signingStyle: automatic` and added `-allowProvisioningUpdates` to the export step. This matches the KB pattern in `~/knowledge/departments/engineering/testflight-autonomous-upload.md` Step 3. **First successful upload will confirm this works.** If it fails, fall back to: regenerate the iOS profile via `bootstrap-asc-profile.sh` adapted for `profileType=IOS_APP_STORE`, then revert to manual signing.

## visionOS TestFlight — first from this fleet

**What we don't know:** per Alex's handoff to this session, no visionOS archive has ever been uploaded to App Store Connect from the Agile Lens fleet. Everything below is an educated guess until exercised.

**Specific open questions when you first run `scripts/ship-testflight.sh --platform visionos`:**

## visionOS TestFlight — first from this fleet

**What we don't know:** per Alex's handoff to this session, no visionOS archive has ever been uploaded to App Store Connect from the Agile Lens fleet. Everything below is an educated guess until exercised.

**Specific open questions when you first run `scripts/ship-testflight.sh --platform visionos`:**

1. **Separate app record?** Apple's newer "multi-platform app" model lets a single App Store Connect record cover iOS + visionOS, but you opt in at record-creation time. If the record was created iOS-only, the visionOS archive will be rejected with something like "missing supported platforms." Fix: recreate the record with both platforms checked, OR add the platform under App Information → App Availability → Add Platform.
2. **visionOS app icon coverage.** Alex flagged that "visionOS requires appicons / app bundle" — this likely means the asset catalog needs the visionOS-specific icon layers (front/middle/back parallax). Our `AppIcon.appiconset/Contents.json` has a `visionos` entry pointing to a single `Icon-visionOS.png`; Apple might reject if the record is visionOS-strict and no parallax layers exist. Field-verify by archiving for visionOS; if it fails asset-catalog validation, split the icon into the three required layers.
3. **Export Compliance on visionOS side.** Should inherit from the same Info.plist build settings (`ITSAppUsesNonExemptEncryption = NO`) since the visionOS build reads the same plist. Confirm it actually does by watching for "Missing Compliance" after visionOS upload.
4. **Build number collision across platforms.** If iOS build 20 and visionOS build 20 both upload to the same app record, Apple may treat them as one or as a conflict. Best practice: bump between platform uploads (iOS 20 → visionOS 21) until we confirm. `scripts/bump-version.sh` handles this.
5. **TestFlight internal-tester delivery on visionOS.** Internal testers need the TestFlight app on visionOS. Not every team member has that yet — Kevin / Henry probably don't. The Dev Team auto-add via `testflight-add-testers.sh` is platform-agnostic, so testers enrolled once should get both iOS and visionOS builds.

**When you resolve each:** strike it out here and document the actual behavior in `~/knowledge/departments/engineering/testflight-autonomous-upload.md` so the next project doesn't have to rediscover.

## Android Play Console — not yet staged

Mirror of the TestFlight handoff doesn't exist. Blocked on: release keystore generation + Play Console app-record click-through. File under `HANDOFF_GOOGLE_PLAY.md` when we get there. For now, Android distribution is "ADB install debug APK," which is fine for the 1-2 Android testers we have.
