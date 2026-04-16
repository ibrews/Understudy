# Handoff — Understudy → TestFlight

Everything scriptable is scripted. The steps below are the browser-only bits I couldn't automate (Apple's App Store Connect doesn't expose app-record creation via CLI).

**Total time budget: ~15 minutes the first time, ~0 minutes after that.** Subsequent uploads are `scripts/bump-version.sh && scripts/ship-testflight.sh`.

---

## Prereqs

- Apple Developer Program membership on team `C624J4S2F8` ✓ (already signed on this machine)
- Xcode 26.4 (Build 17E192) per fleet convention — see `~/knowledge/departments/engineering/ios-distribution.md`
- This repo pulled + up to date
- `dev-control-center` repo checked out alongside this one (for the existing `testflight-add-testers.sh` that `ship-testflight.sh` chains into)

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
7. Move the key to the fleet-standard location (from `testflight-autonomous-upload.md`):
   ```bash
   mkdir -p ~/.private_keys
   mv ~/Downloads/AuthKey_*.p8 ~/.private_keys/
   ```
8. Export the credentials (add to `~/.zshrc` for permanence):
   ```bash
   export ASC_KEY_ID=ABCD123456
   export ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555
   export ASC_KEY_PATH=$HOME/.private_keys/AuthKey_ABCD123456.p8
   ```

---

## Step 3 — Ship the first build

```bash
cd /Users/Shared/Documents/xcodeproj/Understudy
scripts/bump-version.sh          # bumps to 0.18 → 0.19
scripts/ship-testflight.sh       # archives, exports, uploads
```

The script:
1. **Preflight**: verifies API credentials + probes App Store Connect to confirm the bundle ID resolves to a real app record in this team. Fails fast if the record doesn't exist yet.
2. **Archive** for iOS device (Release config, automatic signing, team `C624J4S2F8`).
3. **Export + upload in one pass** via `xcodebuild -exportArchive` with `destination: upload` in `ExportOptions.plist` — no separate `altool` step. Matches the cookbook's canonical flow.
4. **Chain into `testflight-add-testers.sh`** in the sibling `dev-control-center` repo — creates the "Dev Team" beta group + adds `alex@`/`info@`/`crew@agilelens.com` if not already there.
5. **Log to Dev Control Center** (`http://sam:3333/api/apps/understudy/builds`) with status `testflight`.

**Expected duration**: ~3-5 minutes. Output ends with the canonical `** EXPORT SUCCEEDED **` then an upload-complete line.

Flags:
- `--dry-run` — archive + export only, no upload. Good for rehearsing.
- `--no-testers` — skip the tester-add chain (useful if you're shipping to a different group).
- `--skip-preflight` — bypass the ASC-API bundle-ID probe (if you've manually verified the record).
- `--platform visionos` — archives + uploads for visionOS. See the `REVIEW_NEEDED.md` caveat — no visionOS archive has shipped from this fleet yet, so edge cases are unexplored.

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

### 4c. Testers — automatic via the fleet's add-testers script
The ship script automatically chains into `dev-control-center/scripts/testflight-add-testers.sh` after upload. That script:
- Creates a **"Dev Team"** external beta group (fleet convention — same name across every Agile Lens app)
- Adds `alex@agilelens.com`, `info@agilelens.com`, `crew@agilelens.com` as testers
- Does NOT toggle **Automatic Distribution** — that's a one-time click-through you have to do the first time, under TestFlight → Dev Team → Settings → Automatic Distribution. After that, every `scripts/ship-testflight.sh` run auto-delivers to the group.

If you want different testers or a different group, run the add-testers script with `--no-testers` on the ship command and do it manually. Or edit the `TESTERS` array at the top of `dev-control-center/scripts/testflight-add-testers.sh`.

**First-upload edge case**: the external beta group needs the build to finish processing (~5-30 min post-upload) before it can be attached, and external groups require a one-time Apple beta-review that takes 24-48 hours. Internal testers (anyone in the App Store Connect team) can install the moment processing finishes — add them under **TestFlight → Internal Testing → App Store Connect Users**.

### 4d. One-time: enable Automatic Distribution on the Dev Team group
After the first `ship-testflight.sh` run creates the group, open App Store Connect → your app → TestFlight → **Dev Team** → Settings → toggle **Automatic Distribution** ON. From that point forward every uploaded build auto-ships to the Dev Team without further clicks.

---

## Step 5 — Every subsequent build

```bash
scripts/bump-version.sh && scripts/ship-testflight.sh
```

Done. Internal testers get a push notification; external testers get it after Apple rubber-stamps the first build of each marketing version.

---

## Gotchas (from the fleet cookbook + my additions)

- **"No matching profiles found"** → `-allowProvisioningUpdates` (which the script passes) triggers Xcode to fetch/create the profile automatically. If it still fails, run Xcode once to prime the profiles cache, then try again.
- **"ITC.apps.preRelease.binary_notifying_missing_export_compliance"** → `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` is already in the pbxproj. The cookbook confirms this handles compliance automatically in every Agile Lens app so far. If it slips through, manually set the answer in App Store Connect → your build → Export Compliance.
- **Bundle ID case sensitivity** → Apple's records are case-sensitive. Our bundle is `agilelens.Understudy` (lower `a`, capital `U`). If App Store Connect ever shows `agilelens.understudy`, something's wrong in the identifier registration — recreate it.
- **Screen-recording in TestFlight review** → not required for internal testing. Required for external beta review of any build with camera / mic use. When that day comes, make a 20-second Loom showing walking up to a mark + the line firing.
- **macOS Catalyst / Mac** → not in the supported platforms list (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator xros xrsimulator"`). Leave it that way; adding Mac Catalyst at this stage would add a whole review axis.
- **Build-available email spam** → Apple emails you every time a build finishes processing. Disable per-Apple-ID only (no API): App Store Connect → your name top-right → Notifications → uncheck TestFlight "Build Processing Complete". Each team member has to do this in their own account.
- **visionOS unknown** → see `REVIEW_NEEDED.md`. No visionOS archive has shipped from this fleet before; the separate-supported-platforms question is unresolved. First run of `--platform visionos` is the experiment.

---

## Android TestFlight equivalent

Android's internal distribution is **Google Play Console → Internal testing track**. That's a separate handoff — not covered here. The Gradle build + signing config would need a release keystore (none exists yet for Understudy), and Google Play Console is its own browser flow. Happy to write `HANDOFF_GOOGLE_PLAY.md` when we're ready.

---

## File inventory

- `scripts/ship-testflight.sh` — archive + export + upload + chain into tester-add (this doc's Step 3)
- `scripts/bump-version.sh` — single-command version increment
- `TESTFLIGHT_COPY.md` — draft beta description + what's-new notes
- `HANDOFF_TESTFLIGHT.md` — this file
- `PRIVACY.md` — privacy policy, linked from the App Store Connect Beta App Information form

Fleet-shared (lives in `dev-control-center` alongside this repo):
- `scripts/testflight-add-testers.sh` — App Store Connect API → Dev Team beta group + standard testers. Ship script calls this automatically.
- `~/knowledge/departments/engineering/ios-distribution.md` — Agile Lens rules for TestFlight uploads (distribution method, export compliance, Xcode version).
