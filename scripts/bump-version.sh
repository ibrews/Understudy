#!/usr/bin/env bash
#
# bump-version.sh — single-command version bump across all three platforms.
#
# Reads the current iOS MARKETING_VERSION + CURRENT_PROJECT_VERSION from
# Understudy.xcodeproj/project.pbxproj and bumps the build number by one,
# propagating to Android's build.gradle.kts (versionName, versionCode,
# APP_VERSION, APP_BUILD).
#
# Usage:
#   bash scripts/bump-version.sh                       # bump build only (e.g. 0.18(18) → 0.18(19))
#   bash scripts/bump-version.sh --marketing 0.19      # bump both: 0.19(19)
#
# After bumping, you still need to run:
#   scripts/ship-testflight.sh
# or build + install locally.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$REPO_ROOT/Understudy.xcodeproj/project.pbxproj"
ANDROID_GRADLE="$REPO_ROOT/android/app/build.gradle.kts"

NEW_MARKETING=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --marketing) NEW_MARKETING="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Parse current values from pbxproj (first occurrence; both Debug + Release
# carry the same number so one read is enough).
CUR_MARKETING=$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*= ([^;]+);.*/\1/')
CUR_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | sed -E 's/.*= ([^;]+);.*/\1/')
NEW_BUILD=$((CUR_BUILD + 1))

if [[ -z "$NEW_MARKETING" ]]; then
  NEW_MARKETING="$CUR_MARKETING"
fi

echo "iOS + visionOS : $CUR_MARKETING ($CUR_BUILD) → $NEW_MARKETING ($NEW_BUILD)"
echo "Android        : same versionName, versionCode $CUR_BUILD → $NEW_BUILD"

# iOS pbxproj — in-place replace every MARKETING_VERSION / CURRENT_PROJECT_VERSION.
sed -i '' "s/MARKETING_VERSION = ${CUR_MARKETING};/MARKETING_VERSION = ${NEW_MARKETING};/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = ${CUR_BUILD};/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "$PBXPROJ"

# Android — versionName, versionCode, and the two BuildConfig fields.
sed -i '' "s/versionCode = ${CUR_BUILD}/versionCode = ${NEW_BUILD}/g" "$ANDROID_GRADLE"
sed -i '' "s/versionName = \"${CUR_MARKETING}\"/versionName = \"${NEW_MARKETING}\"/g" "$ANDROID_GRADLE"
sed -i '' "s/APP_VERSION\", \"\\\\\"${CUR_MARKETING}\\\\\"\"/APP_VERSION\", \"\\\\\"${NEW_MARKETING}\\\\\"\"/g" "$ANDROID_GRADLE"
sed -i '' "s/APP_BUILD\", \"${CUR_BUILD}\"/APP_BUILD\", \"${NEW_BUILD}\"/g" "$ANDROID_GRADLE"

echo "✓ Bumped."
