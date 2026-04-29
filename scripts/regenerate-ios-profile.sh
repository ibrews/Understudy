#!/usr/bin/env bash
# regenerate-ios-profile.sh — Regenerate "Understudy App Store" iOS App Store
# provisioning profile via the App Store Connect API.
#
# When the existing manual profile gets out of sync with the active Apple
# Distribution cert (e.g. cert was reissued or rotated), the export step of
# ship-testflight.sh fails with "doesn't include signing certificate". This
# script creates a fresh profile pinning the current iOS Distribution cert,
# downloads it to Xcode's profile dir, and replaces any stale profile.
#
# Usage:  bash scripts/regenerate-ios-profile.sh
#
# Requires: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (sourced from ~/.zprofile).

set -euo pipefail

BUNDLE_ID="agilelens.Understudy"
PROFILE_NAME="Understudy App Store"
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$PROFILE_DIR"

ASC_KEY_ID="${ASC_KEY_ID:?need ASC_KEY_ID}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:?need ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:?need ASC_KEY_PATH}"

generate_jwt() {
  local now exp header payload hdr_b64 pl_b64 sig
  now=$(date +%s); exp=$((now + 1200))
  header='{"alg":"ES256","kid":"'$ASC_KEY_ID'","typ":"JWT"}'
  payload='{"iss":"'$ASC_ISSUER_ID'","iat":'$now',"exp":'$exp',"aud":"appstoreconnect-v1"}'
  hdr_b64=$(printf '%s' "$header" | openssl base64 -e -A | tr -- '+/' '-_' | tr -d '=')
  pl_b64=$(printf  '%s' "$payload" | openssl base64 -e -A | tr -- '+/' '-_' | tr -d '=')
  sig=$(printf '%s.%s' "$hdr_b64" "$pl_b64" \
    | openssl dgst -sha256 -sign "$ASC_KEY_PATH" \
    | python3 -c '
import sys, base64
data = sys.stdin.buffer.read()
def parse_der(d):
    i = 2 if d[1] < 0x80 else 2 + (d[1] & 0x7F)
    def read_int(buf, off):
        length = buf[off+1]
        val = buf[off+2:off+2+length]
        if len(val) > 32 and val[0] == 0: val = val[1:]
        return val.rjust(32, b"\x00"), off + 2 + length
    r, i2 = read_int(d, i); s, _ = read_int(d, i2)
    return r + s
print(base64.urlsafe_b64encode(parse_der(data)).rstrip(b"=").decode())
')
  printf '%s.%s.%s' "$hdr_b64" "$pl_b64" "$sig"
}
asc_curl() { curl -sS --globoff "$@" -H "Authorization: Bearer $(generate_jwt)"; }

echo "▶ Looking up bundle ID resource for $BUNDLE_ID…"
BUNDLE_RESOURCE_ID=$(asc_curl -G "https://api.appstoreconnect.apple.com/v1/bundleIds" \
  --data-urlencode "filter[identifier]=$BUNDLE_ID" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); ios = [r["id"] for r in d.get("data",[]) if r.get("attributes",{}).get("platform") in ("IOS", "UNIVERSAL")]; print(ios[0] if ios else "")')
[ -n "$BUNDLE_RESOURCE_ID" ] || { echo "✗ Bundle ID $BUNDLE_ID not found in ASC (filter: IOS/UNIVERSAL platform)"; exit 1; }
echo "  bundle: $BUNDLE_RESOURCE_ID"

echo "▶ Listing distribution certs…"
CERT_ID=$(asc_curl "https://api.appstoreconnect.apple.com/v1/certificates" \
  | python3 -c '
import sys, json
d = json.load(sys.stdin)
PRIORITY = ["DISTRIBUTION", "IOS_DISTRIBUTION"]
found = {}
for c in d.get("data", []):
    attrs = c.get("attributes", {})
    ctype = attrs.get("certificateType", "")
    cid = c.get("id", "")
    name = attrs.get("name", "")
    expires = attrs.get("expirationDate", "")
    print(f"  {cid}  {ctype:24s}  expires {expires}  {name}", file=sys.stderr)
    if ctype in PRIORITY and ctype not in found:
        found[ctype] = cid
for t in PRIORITY:
    if t in found:
        print(found[t]); break
')
[ -n "$CERT_ID" ] || { echo "✗ No DISTRIBUTION/IOS_DISTRIBUTION cert found in ASC"; exit 2; }
echo "  cert  : $CERT_ID"

echo "▶ Looking up Dev Team device list (App Store profiles can include them, harmless)…"
# Skip — not required for AppStore profiles.

echo "▶ Looking for an existing profile named '$PROFILE_NAME'…"
EXISTING_PROFILE_ID=$(asc_curl -G "https://api.appstoreconnect.apple.com/v1/profiles" \
  --data-urlencode "filter[profileType]=IOS_APP_STORE" \
  --data-urlencode "filter[name]=$PROFILE_NAME" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["data"][0]["id"] if d["data"] else "")')

if [ -n "$EXISTING_PROFILE_ID" ]; then
  echo "  Found existing profile $EXISTING_PROFILE_ID — deleting first."
  asc_curl -X DELETE "https://api.appstoreconnect.apple.com/v1/profiles/$EXISTING_PROFILE_ID" \
    -o /tmp/asc-delete-profile.json -w "%{http_code}\n" || true
fi

echo "▶ Creating new IOS_APP_STORE profile '$PROFILE_NAME'…"
export PROFILE_NAME BUNDLE_RESOURCE_ID CERT_ID
PROFILE_PAYLOAD=$(python3 -c '
import json, os
print(json.dumps({
  "data": {
    "type": "profiles",
    "attributes": {
      "name": os.environ["PROFILE_NAME"],
      "profileType": "IOS_APP_STORE"
    },
    "relationships": {
      "bundleId":     {"data": {"type": "bundleIds",    "id": os.environ["BUNDLE_RESOURCE_ID"]}},
      "certificates": {"data": [{"type": "certificates","id": os.environ["CERT_ID"]}]}
    }
  }
}))')

CREATE_RESPONSE=$(asc_curl -X POST "https://api.appstoreconnect.apple.com/v1/profiles" \
  -H "Content-Type: application/json" \
  -d "$PROFILE_PAYLOAD")

PROFILE_CONTENT=$(echo "$CREATE_RESPONSE" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("data",{}).get("attributes",{}).get("profileContent","") or json.dumps(d))')
if [[ "$PROFILE_CONTENT" == \{* ]]; then
  echo "✗ Create failed:"; echo "$PROFILE_CONTENT"; exit 3
fi

PROFILE_FILE="$PROFILE_DIR/$PROFILE_NAME.mobileprovision"
echo "$PROFILE_CONTENT" | base64 -d > "$PROFILE_FILE"
echo "✓ Wrote $PROFILE_FILE"

echo "▶ Verifying profile contents…"
security cms -D -i "$PROFILE_FILE" | plutil -p - | head -30 || true

echo
echo "✓ Profile regenerated. Re-run scripts/ship-testflight.sh."
