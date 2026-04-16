#!/usr/bin/env bash
#
# ship-testflight.sh — archive Understudy and upload to TestFlight.
#
# Idempotent(ish). Archives for iOS by default; pass `--platform visionos`
# for the visionOS archive. Uploads via `xcrun altool --upload-app` with an
# App Store Connect API key (2FA-compatible; no username/password).
#
# Prereqs (one-time):
#   1. App Store Connect record exists for bundle `agilelens.Understudy`.
#      See HANDOFF_TESTFLIGHT.md for the browser steps.
#   2. App Store Connect API key created + downloaded:
#      https://appstoreconnect.apple.com/access/integrations/api
#      Save AuthKey_XXXXXXXXXX.p8 under ~/.appstoreconnect/private_keys/.
#   3. Export the key id + issuer id via env vars, OR pass them on
#      the command line. The script will read:
#         ASC_KEY_ID           (e.g. "ABCD123456")
#         ASC_ISSUER_ID        (UUID from the API Keys page)
#         ASC_KEY_PATH         (optional — auto-discovered under ~/.appstoreconnect/private_keys)
#
# Run:
#   bash scripts/ship-testflight.sh                  # iOS
#   bash scripts/ship-testflight.sh --platform visionos
#   bash scripts/ship-testflight.sh --dry-run        # archive + export, no upload
#
# The script assumes the repo root is two levels above this file.

set -euo pipefail

PLATFORM="ios"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true;  shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/Understudy.xcodeproj"
SCHEME="Understudy"
OUT_DIR="$REPO_ROOT/build/testflight"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_PATH="$OUT_DIR/Understudy-$PLATFORM-$TIMESTAMP.xcarchive"
EXPORT_PATH="$OUT_DIR/Understudy-$PLATFORM-$TIMESTAMP"
EXPORT_OPTIONS_PLIST="$OUT_DIR/ExportOptions-$PLATFORM.plist"

case "$PLATFORM" in
  ios)      DESTINATION='generic/platform=iOS' ;;
  visionos) DESTINATION='generic/platform=visionOS' ;;
  *) echo "Unknown --platform '$PLATFORM' (iOS / visionOS)" >&2; exit 1 ;;
esac

mkdir -p "$OUT_DIR"

# ─── Write ExportOptions.plist ────────────────────────────────────────────
cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>            <string>export</string>
  <key>method</key>                 <string>app-store-connect</string>
  <key>teamID</key>                 <string>C624J4S2F8</string>
  <key>signingStyle</key>           <string>automatic</string>
  <key>stripSwiftSymbols</key>      <true/>
  <key>uploadBitcode</key>          <false/>
  <key>uploadSymbols</key>          <true/>
</dict>
</plist>
PLIST

echo "┌─ Understudy → TestFlight ────────────────────────────────────────"
echo "│  platform    : $PLATFORM"
echo "│  destination : $DESTINATION"
echo "│  archive     : $ARCHIVE_PATH"
echo "│  export      : $EXPORT_PATH"
echo "│  dry-run     : $DRY_RUN"
echo "└──────────────────────────────────────────────────────────────────"

# ─── Archive ──────────────────────────────────────────────────────────────
echo
echo "▶ Archiving for $PLATFORM (this will take a minute)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  | xcbeautify 2>/dev/null || \
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic

# ─── Export .ipa ──────────────────────────────────────────────────────────
echo
echo "▶ Exporting .ipa for App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

IPA_PATH="$(find "$EXPORT_PATH" -name '*.ipa' | head -1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "✗ No .ipa produced; check the export log above." >&2
  exit 2
fi
echo "  → $IPA_PATH"

if [[ "$DRY_RUN" == "true" ]]; then
  echo
  echo "✓ Dry run complete. .ipa ready at:"
  echo "  $IPA_PATH"
  echo
  echo "  Upload manually with:"
  echo "    xcrun altool --upload-app -f '$IPA_PATH' -t $PLATFORM \\"
  echo "      --apiKey \$ASC_KEY_ID --apiIssuer \$ASC_ISSUER_ID"
  exit 0
fi

# ─── Credentials sanity check ─────────────────────────────────────────────
if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  cat <<MSG >&2
✗ Missing App Store Connect API key credentials.

  Set these environment variables before re-running:
    export ASC_KEY_ID=ABCD123456
    export ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555

  See HANDOFF_TESTFLIGHT.md for how to create the API key.
MSG
  exit 3
fi

# ASC_KEY_PATH is optional — altool will look in ~/.appstoreconnect/private_keys
# automatically if the filename matches AuthKey_<KEY_ID>.p8.

# ─── Upload ───────────────────────────────────────────────────────────────
echo
echo "▶ Uploading to App Store Connect…"
xcrun altool --upload-app \
  --file "$IPA_PATH" \
  --type "$PLATFORM" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo
echo "✓ Uploaded. It takes ~5-30 minutes for App Store Connect to process."
echo "  Watch progress at:"
echo "    https://appstoreconnect.apple.com/apps"
echo
echo "  Once processing finishes, add testers under TestFlight → Internal Testing."
