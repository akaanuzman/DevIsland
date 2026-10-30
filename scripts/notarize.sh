#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEV_ISLAND_SIGN_IDENTITY:?Set your Developer ID Application identity.}"
: "${DEV_ISLAND_NOTARY_PROFILE:?Set a notarytool keychain profile.}"
if [ "$DEV_ISLAND_SIGN_IDENTITY" = "-" ]; then echo "A Developer ID identity is required." >&2; exit 1; fi
bash scripts/build-app.sh
xcrun notarytool submit dist/Dev-Island-0.3.6-arm64.zip --keychain-profile "$DEV_ISLAND_NOTARY_PROFILE" --wait
xcrun stapler staple "dist/Dev Island.app"
xcrun stapler validate "dist/Dev Island.app"
spctl --assess --type execute --verbose=2 "dist/Dev Island.app"
bash scripts/package-dmg.sh
codesign --force --timestamp --sign "$DEV_ISLAND_SIGN_IDENTITY" dist/Dev-Island-0.3.6-arm64.dmg
xcrun notarytool submit dist/Dev-Island-0.3.6-arm64.dmg --keychain-profile "$DEV_ISLAND_NOTARY_PROFILE" --wait
xcrun stapler staple dist/Dev-Island-0.3.6-arm64.dmg
xcrun stapler validate dist/Dev-Island-0.3.6-arm64.dmg
ditto -c -k --sequesterRsrc --keepParent "dist/Dev Island.app" dist/Dev-Island-0.3.6-arm64.zip
