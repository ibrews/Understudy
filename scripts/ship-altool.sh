#!/usr/bin/env bash
# ship-altool.sh — The simple TestFlight upload path for Mac developers.
#
# Why this exists: ship-testflight.sh uses xcodebuild's combined
# `destination: upload` mode in ExportOptions.plist, which on this machine
# kept hanging silently during codesign (likely a keychain partition-list
# authorization that needed the password interactively). This script
# splits the steps:
#
#   1. xcodebuild archive (Release, automatic signing, -allowProvisioningUpdates)
#   2. xcodebuild -exportArchive (destination: export) → produces .ipa
#   3. xcrun altool --upload-app -f file.ipa --apiKey ID --apiIssuer ID
#
# altool is a separate tool with its own auth flow. It doesn't go through
# IDEDistribution and avoids the codesign hang.
#
# Usage:
#   bash scripts/ship-altool.sh ios       # archive + upload iOS
#   bash scripts/ship-altool.sh visionos  # archive + upload visionOS
#   bash scripts/ship-altool.sh ios --reuse-archive   # use latest archive
#                                                       (skip archive step)

set -euo pipefail

PLATFORM="${1:-ios}"
REUSE="${2:-}"

case "$PLATFORM" in
  ios)
    DESTINATION='generic/platform=iOS'
    ARCHIVE_PREFIX="Understudy-ios-"
    ALTOOL_TYPE="ios"
    ;;
  visionos)
    DESTINATION='generic/platform=xros'
    ARCHIVE_PREFIX="Understudy-vos-"
    ALTOOL_TYPE="visionos"
    ;;
  *)
    echo "Usage: $0 [ios|visionos] [--reuse-archive]" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ASC_KEY_ID="${ASC_KEY_ID:?need ASC_KEY_ID — source ~/.zprofile first}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:?need ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:?need ASC_KEY_PATH}"

OUT_DIR="$REPO_ROOT/build/testflight"
mkdir -p "$OUT_DIR"

# ─── Archive (or reuse) ──────────────────────────────────────────────────
if [[ "$REUSE" == "--reuse-archive" ]]; then
  ARCHIVE=$(ls -td "$OUT_DIR/${ARCHIVE_PREFIX}"*.xcarchive 2>/dev/null | head -1)
  [ -d "$ARCHIVE" ] || { echo "✗ No archive to reuse for $PLATFORM. Run without --reuse-archive."; exit 2; }
  echo "▶ Reusing archive: $ARCHIVE"
else
  TS=$(date +%Y%m%d-%H%M%S)
  ARCHIVE="$OUT_DIR/${ARCHIVE_PREFIX}${TS}.xcarchive"
  echo "▶ Archiving for $PLATFORM…"
  xcodebuild archive \
    -project Understudy.xcodeproj \
    -scheme Understudy \
    -configuration Release \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=C624J4S2F8 \
    -quiet
  echo "✓ Archived: $ARCHIVE"
fi

# ─── Export ──────────────────────────────────────────────────────────────
EXPORT_PATH="${ARCHIVE%.xcarchive}-export"
EXPORT_OPTS="/tmp/altool-export-options-${PLATFORM}.plist"

cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>                   <string>app-store-connect</string>
  <key>destination</key>              <string>export</string>
  <key>signingStyle</key>             <string>manual</string>
  <key>teamID</key>                   <string>C624J4S2F8</string>
  <key>signingCertificate</key>       <string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>agilelens.Understudy</key>   <string>Understudy App Store</string>
  </dict>
  <key>stripSwiftSymbols</key>        <true/>
  <key>uploadSymbols</key>            <true/>
</dict>
</plist>
PLIST

echo "▶ Exporting .ipa…"
rm -rf "$EXPORT_PATH"
# Manual signing — no -allowProvisioningUpdates (which triggers the
# Cloud Managed cert API call our App Manager key can't make).
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -exportPath "$EXPORT_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -quiet

IPA=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
[ -f "$IPA" ] || { echo "✗ Export didn't produce a .ipa. Check the xcdistributionlogs in /var/folders/."; exit 3; }
echo "✓ Exported: $IPA"

# ─── Upload via altool ────────────────────────────────────────────────────
echo "▶ Uploading via altool…"
xcrun altool --upload-app \
  -f "$IPA" \
  -t "$ALTOOL_TYPE" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo
echo "✓ Uploaded $PLATFORM build. Watch https://appstoreconnect.apple.com/apps for processing (~5–30 min)."
