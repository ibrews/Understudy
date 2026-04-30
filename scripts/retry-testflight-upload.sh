#!/usr/bin/env bash
# retry-testflight-upload.sh — Workaround for codesign hanging during the
# combined export+upload step of ship-testflight.sh.
#
# The combined `destination: upload` mode in ExportOptions.plist invokes
# codesign internally. On this machine, codesign hangs silently when the
# Apple Distribution cert in keychain hasn't been authorized for the
# "codesign" partition list. The workaround: export the .ipa with
# destination:export, then upload with `xcrun altool --upload-app`.
#
# Usage:
#   bash scripts/retry-testflight-upload.sh ios       # re-export + upload iOS
#   bash scripts/retry-testflight-upload.sh visionos  # re-export + upload visionOS
#
# Requires: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (sourced from ~/.zprofile).
#
# IMPORTANT: If codesign still hangs after running this, run this command
# ONCE in a Terminal where you can type a password:
#   security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
#     -k <YOUR_LOGIN_PASSWORD> ~/Library/Keychains/login.keychain-db
# This authorizes codesign to use private keys without prompting.

set -euo pipefail

PLATFORM="${1:-ios}"
case "$PLATFORM" in
  ios)
    ARCHIVE_PATTERN="Understudy-ios-*.xcarchive"
    ALTOOL_TYPE="ios"
    ;;
  visionos)
    ARCHIVE_PATTERN="Understudy-vos-*.xcarchive"
    ALTOOL_TYPE="visionos"
    ;;
  *)
    echo "Usage: $0 [ios|visionos]" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ASC_KEY_ID="${ASC_KEY_ID:?need ASC_KEY_ID — source ~/.zprofile first}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:?need ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:?need ASC_KEY_PATH}"

ARCHIVE=$(ls -td build/testflight/$ARCHIVE_PATTERN 2>/dev/null | head -1)
[ -d "$ARCHIVE" ] || { echo "✗ No $PLATFORM archive found. Run scripts/ship-testflight.sh first."; exit 2; }
echo "▶ Using archive: $ARCHIVE"

EXPORT_PATH="$ARCHIVE.export"
EXPORT_OPTIONS="/tmp/ExportOptions-$PLATFORM-retry.plist"

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>        <string>app-store-connect</string>
  <key>destination</key>   <string>export</string>
  <key>signingStyle</key>  <string>manual</string>
  <key>teamID</key>        <string>C624J4S2F8</string>
  <key>signingCertificate</key>  <string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>agilelens.Understudy</key>  <string>Understudy App Store</string>
  </dict>
  <key>stripSwiftSymbols</key> <true/>
  <key>uploadSymbols</key>     <true/>
  <key>uploadBitcode</key>     <false/>
</dict>
</plist>
PLIST

echo "▶ Exporting .ipa…"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH"

IPA=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
[ -f "$IPA" ] || { echo "✗ No .ipa produced — export failed silently."; exit 3; }
echo "✓ Exported: $IPA"

echo "▶ Uploading via altool (this is the path that doesn't hang)…"
xcrun altool --upload-app \
  -f "$IPA" \
  -t "$ALTOOL_TYPE" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo
echo "✓ Uploaded. Watch https://appstoreconnect.apple.com/apps for processing (~5-30 min)."
