# Handoff — Understudy → Google Play (Internal Testing)

The Android analogue of `HANDOFF_TESTFLIGHT.md`. Same goal: ship a build to a named tester group with one command, after ~30 minutes of one-time browser-only setup.

Unlike TestFlight there is no `scripts/ship-playstore.sh` yet — that's a TODO (see last section). Until it exists, step 6 onwards is a manual upload through the Play Console browser UI. Once we add the Gradle Play Publisher plugin or `fastlane supply`, the final step collapses into `./gradlew publishBundle` the same way TestFlight did for iOS.

**Total time budget: ~30 minutes the first time, ~5 minutes after that (until the publisher is wired).** Once wired: `scripts/bump-version.sh && scripts/ship-playstore.sh`.

---

## Prereqs

- **Google Play Console developer account** — one-time $25 USD registration at https://play.google.com/console. TODO for Alex — this has to be done once by a human with a payment method and a government ID. Use the Agile Lens Google Workspace account (info@agilelens.com) so the app is on a company account, not a personal one.
- **Java 17** — already fleet-standard via Android Studio Preview's bundled JBR at `/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home`. The gradle wrapper in this repo expects JDK 17 (`JavaVersion.VERSION_17`).
- **Android SDK** — in practice this means Android Studio installed. The wrapper fetches build tools automatically.
- **This repo pulled + up to date.**
- **`dev-control-center` checked out alongside** — will hold the future `playstore-add-testers.sh` equivalent.

---

## Step 1 — Create the release signing keystore (one-time, ~3 min)

Unlike Apple (where automatic signing + your distribution cert in the login keychain handle everything), Android requires you to own a keystore file for release signing. If you lose it, you can never update the same app — you'd have to publish a net-new listing. **Back this up.**

Fleet convention is to mirror the iOS key-storage path (`~/.private_keys/`). That directory is already on the gitignore allow-list for "things that must never be committed."

```bash
mkdir -p ~/.private_keys

# 10,000 day validity = ~27 years. Google's minimum is 25 years from now.
keytool -genkey -v \
  -keystore ~/.private_keys/understudy-release.keystore \
  -alias understudy \
  -keyalg RSA -keysize 4096 \
  -validity 10000 \
  -storetype JKS
```

`keytool` prompts for:

- Keystore password (pick a strong one; store in 1Password under **"Understudy Android release keystore"**)
- Key password (use the **same** password — simplifies the Gradle config; Android Studio's default wizard does this too)
- Your name / org / locality — fill in Agile Lens LLC / New York / NY / US. These end up in the certificate; not user-visible.

**Back up the file immediately.** Drop a copy into 1Password as an attachment to the password entry (1Password allows file attachments up to 2 GB; the keystore is ~3 KB). If `~/.private_keys/understudy-release.keystore` ever disappears, restoring from 1Password is the only path back to shipping updates.

### Record the SHA-1 + SHA-256 fingerprints

```bash
keytool -list -v -keystore ~/.private_keys/understudy-release.keystore -alias understudy
```

Paste the SHA-256 into the 1Password entry. You'll need it later if we ever add Google Sign-In, Firebase, or Google Play Integrity — they all bind to the signing cert's SHA-256.

### About Play App Signing (recommended)

Google now enrolls every new app in **Play App Signing** by default. That means:

- Your keystore above becomes the **upload key** (what you sign `.aab`s with before upload).
- Google holds a separate **app signing key** they use to sign the APKs delivered to users.
- If the upload key is ever lost or compromised, Google can rotate it without bricking your listing. This is the fleet-preferred setup — do NOT opt out of Play App Signing in Step 4.

---

## Step 2 — Wire the keystore into `build.gradle.kts` via env vars

**Do not commit passwords.** Fleet convention: passwords come from env vars, never from a `keystore.properties` file checked into git. Your shell exports them from `~/.zshrc` (loaded from 1Password once at session start, or via the Agile Lens `op-load-env` helper once we write it).

Add to `~/.zshrc` (note: values come out of the 1Password entry you created in Step 1):

```bash
export UNDERSTUDY_KEYSTORE_PATH="$HOME/.private_keys/understudy-release.keystore"
export UNDERSTUDY_KEYSTORE_PASSWORD="…from 1Password…"
export UNDERSTUDY_KEY_ALIAS="understudy"
export UNDERSTUDY_KEY_PASSWORD="…from 1Password…"
```

Then `source ~/.zshrc`.

**TODO — edit `android/app/build.gradle.kts`** to reference the env vars. Suggested block (goes inside the `android { }` closure, before `buildTypes`):

```kotlin
signingConfigs {
    create("release") {
        storeFile = System.getenv("UNDERSTUDY_KEYSTORE_PATH")?.let { file(it) }
        storePassword = System.getenv("UNDERSTUDY_KEYSTORE_PASSWORD")
        keyAlias = System.getenv("UNDERSTUDY_KEY_ALIAS")
        keyPassword = System.getenv("UNDERSTUDY_KEY_PASSWORD")
    }
}

buildTypes {
    release {
        isMinifyEnabled = false
        signingConfig = signingConfigs.getByName("release")
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

Guard against unset env vars so debug builds on fresh machines still succeed (they use the auto-generated debug keystore and never touch the release config). A common pattern:

```kotlin
val hasReleaseSigning = listOf(
    "UNDERSTUDY_KEYSTORE_PATH",
    "UNDERSTUDY_KEYSTORE_PASSWORD",
    "UNDERSTUDY_KEY_ALIAS",
    "UNDERSTUDY_KEY_PASSWORD",
).all { System.getenv(it) != null }

// …then only attach signingConfig if hasReleaseSigning is true; otherwise
// Gradle will emit an unsigned release .aab and the ship script aborts.
```

This doc is deliberately not making that edit — it's your first code change when you pick this up. Run `./gradlew :app:assembleRelease` after editing; if it completes and the APK is signed (`apksigner verify --verbose`), you're good.

---

## Step 3 — Build a signed `.aab` (App Bundle)

Google Play requires `.aab` (Android App Bundle), not `.apk`, for all new apps since August 2021. Gradle's `bundleRelease` target produces one.

```bash
cd /Users/Shared/Documents/xcodeproj/Understudy/android
export JAVA_HOME="/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

./gradlew :app:bundleRelease
```

The signed bundle lands at:

```
android/app/build/outputs/bundle/release/app-release.aab
```

Sanity check the signature before upload:

```bash
# Requires build-tools on PATH — easiest route is symlinking from Android Studio:
#   export PATH="$HOME/Library/Android/sdk/build-tools/34.0.0:$PATH"
bundletool validate --bundle=app/build/outputs/bundle/release/app-release.aab
```

If `validate` spits out your applicationId, versionCode, and "signed: true," you're ready.

---

## Step 4 — Create the Play Console app record (one-time, ~5 min)

Open https://play.google.com/console → **Create app**.

1. **App name**: `Understudy`
2. **Default language**: `English (United States) — en-US`
3. **App or game**: `App`
4. **Free or paid**: `Free`
5. **Declarations**:
   - Developer Program Policies — check (read the summary first)
   - US export laws — check (our encryption usage is exempt, same as the iOS answer)
6. **Create app**.

You're dropped onto the dashboard with a setup checklist on the left. Work top-to-bottom; the checklist is the single source of truth for "what does Google require before you can upload." The items below map to that sidebar.

### 4a. App access

Most of Understudy is accessible without login (there is no login). Pick **All functionality is available without special access**. If you ever add a rehearsal license tier that gates features, switch this to "All or some functionality is restricted" and upload a demo-account video.

### 4b. Ads

**No, my app does not contain ads.** (It doesn't.)

### 4c. Content rating

Fill in the questionnaire. For Understudy (a theater rehearsal tool, no violence / sex / gambling / drug references / user-to-user communication of inappropriate content):

- **Category**: `Utility, Productivity, Communication, or Other`
- **Violence**: all "No"
- **Sexuality**: all "No"
- **Language**: "No" (the bundled Shakespeare texts contain some archaic insults — "thou knave" etc. — but these are not the user-to-user messaging Google is asking about)
- **Controlled substances**: all "No"
- **Gambling / simulated gambling**: all "No"
- **User-generated content / user-to-user sharing**: **YES, kind of** — room codes let users share blocking documents over LAN or a user-configured relay. Google's definition of UGC leans toward publicly-discoverable content (forums, chat). Ours is private-by-code and LAN-scoped. The honest answer is: users can exchange blocking docs, but the app provides no discovery or moderation surface. Pick "Yes" to be safe and describe the moderation approach as "None — LAN / room-code-scoped sharing only, no public feed."

**Expected IARC rating**: PEGI 3 / ESRB Everyone. Google translates the questionnaire automatically.

### 4d. Target audience and content

- **Target audience**: `18+` is the cleanest answer. The app is a professional-theater tool; "Ages 13-17" would drag in a pile of children's-privacy (COPPA/GDPR-K) obligations we don't need.
- **Children's Online Privacy Protection Act (COPPA) disclosures**: N/A when target audience is 18+.

### 4e. News app

**No.**

### 4f. COVID-19 contact tracing and status apps

**No.**

### 4g. Data safety

This form is Google's version of Apple's App Privacy labels. Cross-reference `PRIVACY.md`. Fill in:

- **Does your app collect or share any of the required user data types?** **No** — Understudy does not collect data. All processing is on-device; pose broadcasts go device-to-device on a LAN the user controls; there is no Agile Lens server storing anything.
- **Is all of the user data collected by your app encrypted in transit?** N/A (no data collection). If Google forces a Yes/No, answer Yes — Bonjour/WebSocket sessions can be TLS when the user runs their own wss:// relay, and MPC encrypts by default on Apple's side. Flag if Google's form demands a certificate; we don't have one.
- **Do you provide a way for users to request that their data be deleted?** N/A — there is nothing collected to delete. Link to `PRIVACY.md`'s "Your rights" section.

**Privacy policy URL (required even for internal testing)**: `https://github.com/ibrews/Understudy/blob/main/PRIVACY.md`

### 4h. Advertising ID

**No, my app does not use advertising ID.** (It doesn't. We don't integrate AdMob, Firebase Analytics, or any SDK that touches the ad ID.)

### 4i. Government apps

**No.**

### 4j. Financial features

**None.**

### 4k. Health apps

**None.**

### 4l. Main store listing

The Play Store listing minimum for internal testing is surprisingly permissive — Google will let you upload an internal-testing build with just the title + short description + full description + feature graphic + phone screenshots. Everything else can stay blank until you promote to closed or open testing.

See `GOOGLE_PLAY_COPY.md` for drafts.

Required fields:
- **App name**: `Understudy` (already set)
- **Short description** (80 chars)
- **Full description** (4000 chars)
- **App icon** (512×512 PNG, 32-bit with alpha) — reuse the iOS 1024×1024 icon, scaled and flattened
- **Feature graphic** (1024×500 PNG/JPG) — one hero shot of marks + teleprompter
- **Phone screenshots** (at least 2, up to 8, 16:9 or 9:16 aspect, 320-3840 px on each edge)

Optional but nice:
- **7-inch tablet screenshots**, **10-inch tablet screenshots**, **Android TV / Wear / Auto** — skip.
- **Promo video** (YouTube URL) — skip for internal testing.

---

## Step 5 — Create the Internal Testing track + add testers (one-time, ~2 min)

Play Console sidebar → **Testing → Internal testing → Create new release** (we'll do the upload in Step 6). First do the tester list.

Click the **Testers** tab at the top of the Internal testing page.

1. **Create email list** → name it `Dev Team` (fleet convention — same name Android-side as we use for the TestFlight group).
2. Paste the tester emails, one per line:
   ```
   alex@agilelens.com
   info@agilelens.com
   crew@agilelens.com
   ```
3. Save.
4. Under **"How testers join your test"**, copy the **opt-in URL**. It looks like `https://play.google.com/apps/internaltest/1234567890123456789`. Each tester has to click that URL once with their Google-Play-linked Google account to accept the invite. Email the URL to the three testers now — they can accept before the first build even exists.

Internal testing has **no review**. Unlike external/open testing (which gets rubber-stamped by Google in a few hours to a day), internal builds are available to the opted-in testers within ~5 minutes of upload. This is the Android equivalent of TestFlight internal testing.

Max 100 testers per internal-testing app. We'll never hit that.

---

## Step 6 — Upload the `.aab` + roll out

Play Console → **Testing → Internal testing → Create new release**.

1. **App signing** — on first upload, Google asks which app-signing flow you want. Pick **"Use Play App Signing"** (the default). Google will generate its own app-signing key; your `.aab` will be signed by your upload key (Step 1); the APKs delivered to users will be re-signed by Google's key. This is what you want.
2. **Upload bundle** → drag `android/app/build/outputs/bundle/release/app-release.aab`.
3. **Release name** — auto-fills with `versionName (versionCode)` from the bundle. Accept the default.
4. **Release notes** — paste from `GOOGLE_PLAY_COPY.md` → "What to test" section. Google localizes per-language; since we only ship en-US, one block suffices.
5. **Save** → **Review release** → **Start rollout to Internal testing** → confirm.

Rollout is immediate. Testers who've accepted the opt-in URL see the update in Play Store within ~5 minutes (force-refresh via `Play Store → menu → My apps & games → Updates`).

---

## Step 7 — Every subsequent build

**Current manual flow** (until `ship-playstore.sh` exists):

```bash
scripts/bump-version.sh                         # same as iOS — bumps versionCode + versionName in both
cd android
./gradlew :app:bundleRelease                    # produces app-release.aab
```

Then: Play Console → Internal testing → Create new release → upload → rollout. ~2 minutes per ship.

**Future automated flow** (TODO — see last section):

```bash
scripts/bump-version.sh && scripts/ship-playstore.sh
```

Done. Testers pick it up on next Play Store refresh.

---

## Gotchas

- **Signing config leak** — if someone adds `keystore.properties` with plaintext passwords and accidentally commits it, the release key is compromised and has to be rotated via Play App Signing's key upgrade flow (painful; requires Google support ticket). Keep passwords in env vars from 1Password only. Add `keystore.properties`, `*.keystore`, and `*.jks` to `android/.gitignore` **before** the first build (pre-flight check for whoever wires up Step 2).
- **minSdk mismatches** — we're at `minSdk = 26` (Android 8.0). Dropping below that cuts out `androidx.xr.projected:projected` (Android XR requires 30+ in practice) and breaks the LAN-discovery library. Don't lower it without re-verifying Android XR companion flow. Raising it is fine — minSdk 30 (Android 11) is a reasonable future bump if we need modern NSD APIs.
- **Target API level requirement — Google's rolling deadline.** As of April 2026, new apps must `targetSdk >= 34` and updates to existing apps must `targetSdk >= 33`. We're at `targetSdk = 36`, so we're compliant *today* but the target-API floor rises every August. The rule of thumb: **latest stable Android minus one year**. When Android 17 ships (late 2026), we'll have until August 2027 to bump to `targetSdk = 36` minimum. Set a calendar reminder.
- **`versionCode` is monotonic, not marketing** — `versionCode` must strictly increase with every upload to the same track. `bump-version.sh` handles this, but if you ever upload a test `.aab` with a lower versionCode by hand, Play rejects it with "Version code X has already been used" and you have to bump again. Don't reuse versionCodes, even across tracks.
- **Play App Signing opt-in is irreversible per app** — once you opt in on first upload (Step 6), you can't opt out. That's fine — we want to be in — but don't click through the consent without reading it.
- **`.aab` vs `.apk` confusion** — Google Play requires `.aab` for new apps since Aug 2021. Don't try to upload the `app-release.apk` from `build/outputs/apk/release/` — Play will reject with "You need to use the Android App Bundle when targeting Android 11+." Always `bundleRelease`, never `assembleRelease` for shipping.
- **Play Console bundle upload size** — uncompressed `.aab` over 150 MB triggers the asset-delivery split requirement. We're currently well under (few MB), but if we ever bundle large meshes or audio, we'd need Play Asset Delivery. Flag that before it happens.
- **Internal testing needs at least one tester** — Google won't let you save a release to an empty tester list. The "Dev Team" email list from Step 5 must exist and have at least one address before the first upload.
- **Opt-in URL is per-track, not per-app** — if you ever spin up a separate closed testing track, it gets its own URL. Don't reuse the internal-testing URL for a closed beta — testers would land on the wrong track.
- **ARCore availability** — `com.google.ar:core:1.44.0` requires Google Play Services for AR on the device. Some non-Google-Services devices (Huawei since the trade ban, some Kindle Fires, GrapheneOS) can't install the ARCore services and will fall back to our no-tracking stub. Google Play filters for this automatically on the store listing — devices without ARCore support just won't see the app as installable. Fine for internal testing but worth knowing if a tester reports "can't find app in Play Store."
- **targetSdk and SDK 35+ edge-to-edge enforcement** — Android 15 (API 35) made edge-to-edge display mandatory for apps targeting SDK 35+. Understudy's Compose UI already handles insets, but any new full-screen activity that hard-codes system-bar assumptions will break. Relevant if anyone adds a new native Activity outside Compose.
- **Play Console 2-step verification required** — Google enforces 2SV on the developer account. If info@agilelens.com doesn't have it enabled (via Google Workspace admin), console login will fail. Check first.

---

## Data-safety form — quick reference

Cross-ref `PRIVACY.md`. Short version for the Play Console form:

| Data type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Personal info (name, email, etc.) | No | No | — |
| Financial info | No | No | — |
| Health and fitness | No | No | — |
| Messages | No | No | — |
| Photos and videos | No | No | — |
| Audio files | No | No | — |
| Files and docs | No | No | — |
| Calendar | No | No | — |
| Contacts | No | No | — |
| App activity | No | No | — |
| Web browsing | No | No | — |
| App info and performance | No | No | — |
| Device or other IDs | No | No | — |

Declare: **"No data collected."** Google still requires the privacy-policy URL and a statement that all processing is on-device / LAN-scoped.

---

## TODO — automation roadmap

In priority order. Each knocks minutes off every future ship:

1. **`scripts/ship-playstore.sh`** — archive, bundle, upload, roll out. Two real options:
   - **Gradle Play Publisher plugin** (`com.github.triplet.play` — maintained, Kotlin-first). Adds a few lines to `build.gradle.kts`, then `./gradlew publishBundle` uploads to the Internal track. Auth via a Google Play Developer API service-account JSON. Closest match to the iOS script's style — everything's inside Gradle. *Recommended path.*
   - **`fastlane supply`** — Ruby-based, the industry classic. More features (metadata sync, screenshot upload), but adds a Ruby + `bundler` dependency to the fleet. Only worth it if we want metadata-as-code across the board.
2. **Google Play Developer API service account** — before `ship-playstore.sh` can upload non-interactively, we need a service-account JSON key:
   - https://console.cloud.google.com → create project → enable **Google Play Android Developer API** → create service account → download JSON key to `~/.private_keys/understudy-playstore-publisher.json`
   - Play Console → Users and permissions → invite the service-account email → grant **Release manager** role (minimum scope that can push builds)
   - Env var convention to match iOS: `export PLAY_PUBLISHER_JSON=$HOME/.private_keys/understudy-playstore-publisher.json`
3. **`scripts/playstore-add-testers.sh`** — parallel to `dev-control-center/scripts/testflight-add-testers.sh`. Play Developer API endpoint is `edits.tracks.patch` on the Internal track. Reuses the same `TESTERS` array convention so the three emails stay in sync across platforms.
4. **CI hook** — optional — push a new `.aab` on every tag. Same GitHub Actions pattern as the iOS side, once the iOS side has one.

---

## File inventory

- `HANDOFF_GOOGLE_PLAY.md` — this file
- `GOOGLE_PLAY_COPY.md` — short + long description + release notes drafts
- `PRIVACY.md` — privacy policy (shared with iOS; already cross-platform in wording)
- `android/app/build.gradle.kts` — needs the `signingConfigs` block from Step 2 added before first release build
- `scripts/ship-playstore.sh` — **does not exist yet**, see TODO section
- `scripts/bump-version.sh` — already handles Android `versionCode`/`versionName` alongside iOS

Fleet-shared (future, in `dev-control-center`):
- `scripts/playstore-add-testers.sh` — not yet written
- `~/knowledge/departments/engineering/android-distribution.md` — KB entry to match `ios-distribution.md`; capture the signing convention + service-account workflow the first time we do a real ship
