#!/usr/bin/env bash
#
# ship-testflight.sh — archive Understudy and upload to TestFlight.
#
# Direct implementation of the fleet workflow documented in
# ~/knowledge/departments/engineering/testflight-autonomous-upload.md
# (updated 2026-04-16). Uses ExportOptions.plist with destination:upload
# so archive → export → upload happens in a single xcodebuild call.
#
# Prereqs (one-time per machine):
#   1. App Store Connect API key:
#      https://appstoreconnect.apple.com/access/integrations/api
#      Save AuthKey_XXXXXXXXXX.p8 under ~/.private_keys/.
#   2. Environment variables (add to ~/.zshrc):
#         export ASC_KEY_ID="ABCD123456"
#         export ASC_ISSUER_ID="11111111-2222-3333-4444-555555555555"
#         export ASC_KEY_PATH="$HOME/.private_keys/AuthKey_ABCD123456.p8"
#   3. App Store Connect app record for bundle agilelens.Understudy.
#      See HANDOFF_TESTFLIGHT.md for the browser steps.
#
# Prereqs (one-time per app — created by the record-creation browser steps):
#   - Distribution cert in login keychain (auto-created by Xcode the first
#     time -allowProvisioningUpdates runs against a bundle you can sign).
#   - ITSAppUsesNonExemptEncryption = NO in Info.plist / pbxproj. Already
#     set in this project's build settings.
#
# Run:
#   scripts/ship-testflight.sh                  # iOS (default)
#   scripts/ship-testflight.sh --platform visionos
#   scripts/ship-testflight.sh --dry-run        # archive only, no upload
#   scripts/ship-testflight.sh --no-testers     # skip Dev Team auto-add
#   scripts/ship-testflight.sh --skip-preflight # don't probe bundle ID

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────
PLATFORM="ios"
DRY_RUN=false
ADD_TESTERS=true
DO_PREFLIGHT=true

BUNDLE_ID="agilelens.Understudy"
TEAM_ID="C624J4S2F8"    # Agile Lens LLC, per ios-distribution.md
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/Understudy.xcodeproj"
SCHEME="Understudy"
OUT_DIR="$REPO_ROOT/build/testflight"

# ─── CLI parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true;  shift ;;
    --no-testers) ADD_TESTERS=false; shift ;;
    --skip-preflight) DO_PREFLIGHT=false; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

case "$PLATFORM" in
  ios)      DESTINATION='generic/platform=iOS' ;;
  visionos) DESTINATION='generic/platform=visionOS' ;;
  *) echo "Unknown --platform '$PLATFORM' (ios / visionos)" >&2; exit 1 ;;
esac

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_PATH="$OUT_DIR/Understudy-$PLATFORM-$TIMESTAMP.xcarchive"
EXPORT_PATH="$OUT_DIR/Understudy-$PLATFORM-$TIMESTAMP"
EXPORT_OPTIONS_PLIST="$OUT_DIR/ExportOptions-$PLATFORM.plist"
mkdir -p "$OUT_DIR"

# ─── Preflight: credentials ───────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
  for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    if [[ -z "${!var:-}" ]]; then
      cat <<MSG >&2
✗ Missing \$$var.

  Fleet convention (from testflight-autonomous-upload.md):
    export ASC_KEY_ID=ABCD123456
    export ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555
    export ASC_KEY_PATH=\$HOME/.private_keys/AuthKey_ABCD123456.p8

  See HANDOFF_TESTFLIGHT.md for how to create the API key.
MSG
      exit 3
    fi
  done
  if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo "✗ ASC_KEY_PATH file does not exist: $ASC_KEY_PATH" >&2
    exit 3
  fi
fi

# ─── Preflight: bundle-ID collision check via ASC API ─────────────────────
# Avoid a failed upload later by checking if the bundle exists in this team's
# App Store Connect before we bother archiving. The record MUST exist before
# upload — but we distinguish "record exists" from "record exists under a
# different team / name" and alert appropriately.
if [[ "$DO_PREFLIGHT" == "true" && "$DRY_RUN" == "false" ]]; then
  echo "▶ Preflight — checking App Store Connect for $BUNDLE_ID…"

  # Source the fleet JWT helper so we get the correct DER→raw R||S signature
  # conversion. Rolling our own openssl produces DER-encoded ECDSA which JWT
  # ES256 rejects (401). Per testflight-app-record-creation.md "Known Traps".
  ASC_JWT_SH="$REPO_ROOT/../dev-control-center/scripts/asc-jwt.sh"
  if [[ ! -f "$ASC_JWT_SH" ]]; then
    echo "✗ Preflight needs $ASC_JWT_SH — clone dev-control-center alongside" >&2
    echo "  this repo or re-run with --skip-preflight." >&2
    exit 3
  fi
  # shellcheck disable=SC1090
  source "$ASC_JWT_SH"
  TOKEN=$(generate_jwt)

  # curl --globoff keeps literal [] in the URL; --data-urlencode handles
  # the filter= payload safely. asc_curl already does --globoff but we
  # use a raw curl here so preflight doesn't hard-depend on its stderr
  # conventions.
  FOUND_APPS=$(curl -sS --globoff -G \
    -H "Authorization: Bearer $TOKEN" \
    --data-urlencode "filter[bundleId]=$BUNDLE_ID" \
    "https://api.appstoreconnect.apple.com/v1/apps" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" \
    2>/dev/null || echo 0)

  if [[ "$FOUND_APPS" == "0" ]]; then
    cat <<MSG >&2
✗ No App Store Connect record found for $BUNDLE_ID.

  This means either:
   1. You haven't created the record yet (see HANDOFF_TESTFLIGHT.md Step 1),
      OR
   2. The bundle is registered under a different Apple account that this
      API key can't see.

  If you just registered the identifier at developer.apple.com, you still
  need the App Store Connect record at https://appstoreconnect.apple.com/apps.

  Override with --skip-preflight if you're sure the record exists.
MSG
    exit 4
  fi
  echo "  ✓ App record exists in this team."
fi

# ─── ExportOptions.plist ──────────────────────────────────────────────────
# destination: upload means a single -exportArchive invocation also uploads
# to App Store Connect — no separate altool call needed. Matches the
# cookbook's Step 3 quick-reference flow.
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>        <string>app-store-connect</string>
  <key>destination</key>   <string>$( if [[ "$DRY_RUN" == "true" ]]; then echo export; else echo upload; fi )</string>
  <key>signingStyle</key>  <string>automatic</string>
  <key>teamID</key>        <string>$TEAM_ID</string>
  <key>stripSwiftSymbols</key> <true/>
  <key>uploadSymbols</key>     <true/>
  <key>uploadBitcode</key>     <false/>
</dict>
</plist>
PLIST

echo "┌─ Understudy → TestFlight ────────────────────────────────────────"
echo "│  platform    : $PLATFORM"
echo "│  destination : $DESTINATION"
echo "│  archive     : $ARCHIVE_PATH"
echo "│  export path : $EXPORT_PATH"
echo "│  dry-run     : $DRY_RUN"
echo "│  add testers : $ADD_TESTERS"
echo "└──────────────────────────────────────────────────────────────────"

# ─── Archive ──────────────────────────────────────────────────────────────
echo
echo "▶ Archiving for $PLATFORM (Release + automatic signing)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID"

# ─── Export (+ upload in non-dry mode via destination:upload) ─────────────
echo
if [[ "$DRY_RUN" == "true" ]]; then
  echo "▶ Exporting .ipa (dry-run, no upload)…"
else
  echo "▶ Exporting + uploading to App Store Connect in one pass…"
  # Apple's xcodebuild reads the API creds from env vars with these names.
  export API_PRIVATE_KEYS_DIR="$(dirname "$ASC_KEY_PATH")"
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH"

if [[ "$DRY_RUN" == "true" ]]; then
  IPA_PATH="$(find "$EXPORT_PATH" -name '*.ipa' | head -1)"
  echo
  echo "✓ Dry run complete. .ipa ready at:"
  echo "  $IPA_PATH"
  exit 0
fi

echo
echo "✓ Uploaded. App Store Connect processes builds in ~5-30 min."
echo "  Watch:  https://appstoreconnect.apple.com/apps"

# ─── Chain into Dev Team tester-add ───────────────────────────────────────
TESTERS_SCRIPT="$REPO_ROOT/../dev-control-center/scripts/testflight-add-testers.sh"
if [[ "$ADD_TESTERS" == "true" && -x "$TESTERS_SCRIPT" ]]; then
  echo
  echo "▶ Ensuring Dev Team beta group + standard testers…"
  if "$TESTERS_SCRIPT" "$BUNDLE_ID"; then
    echo "✓ Testers ensured."
  else
    echo "⚠ testflight-add-testers.sh failed — App Store Connect may still be"
    echo "  processing the build. Re-run after ~5 min:"
    echo "    $TESTERS_SCRIPT $BUNDLE_ID"
  fi
elif [[ "$ADD_TESTERS" == "true" ]]; then
  echo
  echo "⚠ dev-control-center/scripts/testflight-add-testers.sh not found."
  echo "  Add testers manually or check out the fleet repo alongside this one."
fi

# ─── Log to Dev Control Center ────────────────────────────────────────────
# Per testflight-autonomous-upload.md — every upload should get a build
# record in the fleet dashboard.
if command -v curl >/dev/null 2>&1; then
  VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PROJECT/project.pbxproj" | sed -E 's/.*= ([^;]+);.*/\1/')"
  BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT/project.pbxproj" | sed -E 's/.*= ([^;]+);.*/\1/')"
  curl -s -X POST http://sam:3333/api/apps/understudy/builds \
    -H "Content-Type: application/json" \
    -d "{\"version\":\"$VERSION\",\"build_number\":$BUILD,\"status\":\"testflight\",\"platform\":\"$PLATFORM\",\"notes\":\"uploaded via ship-testflight.sh\"}" \
    >/dev/null || true
fi
