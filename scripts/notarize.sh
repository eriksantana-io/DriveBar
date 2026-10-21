#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DRIVEBAR_SIGNING_IDENTITY:?Set DRIVEBAR_SIGNING_IDENTITY to your Developer ID Application certificate name or SHA-1 identity.}"
PROFILE="${1:-DriveBar-notary}"
APP="$PWD/dist/DriveBar.app"
SUBMISSION="$PWD/dist/DriveBar-notarization.zip"
RESULT="$PWD/dist/notarization-result.json"
RELEASE="$PWD/dist/DriveBar.zip"

# Fail before rebuilding if this Mac cannot access the selected signing key.
security find-identity -v -p codesigning | grep -F -- "$DRIVEBAR_SIGNING_IDENTITY" >/dev/null || {
  echo "The requested signing identity is unavailable in your Keychain." >&2
  exit 1
}
bash scripts/build.sh
codesign -dv --verbose=4 "$APP" 2> "$PWD/dist/signature-details.txt"
grep -q '^Authority=Developer ID Application:' "$PWD/dist/signature-details.txt" || {
  echo "Distribution requires a Developer ID Application certificate." >&2
  exit 1
}
ditto -c -k --sequesterRsrc --keepParent "$APP" "$SUBMISSION"
xcrun notarytool submit "$SUBMISSION" --keychain-profile "$PROFILE" --wait --output-format json > "$RESULT"
/usr/bin/plutil -extract status raw -o - "$RESULT" | grep -qx 'Accepted' || {
  echo "Notarization was not accepted. See $RESULT and retrieve the submission log with notarytool log." >&2
  exit 1
}
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute --verbose=2 "$APP"
# Repackage AFTER stapling so offline users receive the ticket too.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$RELEASE"
echo "Signed, notarized release: $RELEASE"
