# Handoff — Understudy → TestFlight

Everything scriptable is scripted. The steps below are the browser-only bits I couldn't automate (Apple's App Store Connect doesn't expose app-record creation via CLI).

**Total time budget: ~15 minutes the first time, ~0 minutes after that.** Subsequent uploads are `scripts/bump-version.sh && scripts/ship-testflight.sh`.

---

## Prereqs

- Apple Developer Program membership on team `C624J4S2F8` ✓ (already signed on this machine)
- Xcode 26.1.1+ ✓
- This repo pulled + up to date

---

## Step 1 — Create the App Store Connect record (one-time, ~3 min)

Open https://appstoreconnect.apple.com/apps

1. Click **"+" → New App**.
2. **Platforms**: check both **iOS** and **visionOS**. (One app record covers both — same bundle, two platform ports.)
3. **Name**: `Understudy`
4. **Primary Language**: English (U.S.)
5. **Bundle ID**: pick `agilelens.Understudy` from the dropdown. If it's not in the list, go to https://developer.apple.com/account/resources/identifiers/list first and register it (team `C624J4S2F8`, capabilities: none needed — no push, no iCloud, no Sign in with Apple).
6. **SKU**: `UNDERSTUDY-001` (freeform — not user-visible)
7. **User Access**: "Full Access" unless you plan to delegate.
8. **Create**.

You're dropped into the app detail page. Don't worry about the public App Store metadata yet — that's only required when you submit for review. TestFlight only needs the minimum.

---

## Step 2 — Create an App Store Connect API key (one-time, ~2 min)

Apple's modern, 2FA-compatible credential for CLI uploads. You do this once and the key lives on your machine.

Open https://appstoreconnect.apple.com/access/integrations/api

1. Click **Keys → Team Keys → Generate API Key** (if this is your first, you'll see a "Request Access" click-through; approve it).
2. **Name**: `Understudy-Ship`
3. **Access**: `App Manager` (minimum role that can upload builds).
4. **Generate**.
5. Apple shows a **one-time download link** for `AuthKey_XXXXXXXXXX.p8`. Download it.
6. Note the **Key ID** (e.g. `ABCD123456`) and the **Issuer ID** (UUID at the top of the Keys page).
7. Move the key to the expected location:
   ```bash
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
   ```
8. Export the credentials for the ship script (add to `~/.zshrc` for permanence):
   ```bash
   export ASC_KEY_ID=ABCD123456
   export ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555
   ```

---

## Step 3 — Ship the first build

```bash
cd /Users/Shared/Documents/xcodeproj/Understudy
scripts/bump-version.sh          # bumps to 0.18 → 0.19
scripts/ship-testflight.sh       # archives, exports, uploads
```

The script:
1. Archives Release config for iOS device.
2. Exports an `.ipa` with App Store distribution signing.
3. Uploads via `xcrun altool --upload-app` using your API key.

**Expected duration**: ~3-5 minutes. Output ends with *"Uploaded. It takes ~5-30 minutes for App Store Connect to process."*

Want to rehearse the pipeline without uploading? `scripts/ship-testflight.sh --dry-run`.

For visionOS: `scripts/ship-testflight.sh --platform visionos`. Separate archive, same app record.

---

## Step 4 — Tell App Store Connect you're ready for testing (one-time, ~5 min)

Back in App Store Connect → your Understudy app → **TestFlight** tab.

Apple requires a few bits before they'll let *anyone* test, even internally:

### 4a. Export Compliance
Already set in `project.pbxproj` (`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`). Apple should auto-detect this and mark the build as compliant within a few minutes of upload.

### 4b. Beta App Information
Under **TestFlight → Test Information**:
- **Beta App Description**: paste from `TESTFLIGHT_COPY.md` (draft included).
- **Feedback Email**: `info@agilelens.com`
- **Marketing URL**: `https://github.com/ibrews/Understudy` (or wherever you want testers to land)
- **Privacy Policy**: required. Shortest path: write a one-pager on the repo wiki that says "Understudy runs all AR tracking and speech recognition on-device. Pose updates and blocking data are broadcast only to devices you choose to join your session. No analytics, no accounts, no server-side storage." Link to it here.

### 4c. Internal Testers
Under **TestFlight → Internal Testing**:
1. **Create New Group** → name it `Team`.
2. **Builds**: add the build you just uploaded.
3. **Testers**: add anyone in your App Store Connect team (Kevin, Henry, etc.). Up to 100 internal testers, no review needed.

Internal testers receive an email → open TestFlight → install.

### 4d. External testers (optional, later)
If you want to invite people outside the team (actors, directors you know), create an **External Group** instead. Apple requires a short beta review for each *major* version (build 1 of each `MARKETING_VERSION`); usually clears in 24-48 hours. After that, point releases don't re-review.

---

## Step 5 — Every subsequent build

```bash
scripts/bump-version.sh && scripts/ship-testflight.sh
```

Done. Internal testers get a push notification; external testers get it after Apple rubber-stamps the first build of each marketing version.

---

## Gotchas I've hit before

- **"No matching profiles found"** → run `scripts/ship-testflight.sh --dry-run` once to let Xcode auto-create the distribution profile, then re-run without `--dry-run`.
- **"ITC.apps.preRelease.binary_notifying_missing_export_compliance"** → App Store Connect wants the compliance answer. It's set via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` which we have — but occasionally Apple doesn't pick it up automatically. Manually set the answer in App Store Connect → your build → Export Compliance.
- **visionOS separate distribution profile** → uploading both iOS and visionOS archives to the same app record takes two ship-script runs. Order doesn't matter; Apple links them by bundle ID.
- **Bundle ID case sensitivity** → Apple's records are case-sensitive. Our bundle is `agilelens.Understudy` (lower `a`, capital `U`). If App Store Connect ever shows `agilelens.understudy`, something's wrong in the identifier registration — recreate it.
- **Screen-recording in TestFlight review** → not required for internal testing. Required for external beta review of any build with camera / mic use. When that day comes, make a 20-second loom showing walking up to a mark + the line firing.
- **macOS Catalyst / Mac** → not in the supported platforms list (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator xros xrsimulator"`). Leave it that way; adding Mac Catalyst at this stage would add a whole review axis.

---

## Android TestFlight equivalent

Android's internal distribution is **Google Play Console → Internal testing track**. That's a separate handoff — not covered here. The Gradle build + signing config would need a release keystore (none exists yet for Understudy), and Google Play Console is its own browser flow. Happy to write `HANDOFF_GOOGLE_PLAY.md` when we're ready.

---

## File inventory

- `scripts/ship-testflight.sh` — archive + export + upload (this doc's Step 3)
- `scripts/bump-version.sh` — single-command version increment
- `TESTFLIGHT_COPY.md` — draft beta description + what's-new notes
- `HANDOFF_TESTFLIGHT.md` — this file
