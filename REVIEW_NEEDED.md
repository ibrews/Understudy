# Review Needed

Things I know the answer to today, but might bite us under new conditions. Clear an item by confirming the behavior on hardware and deleting it.

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
