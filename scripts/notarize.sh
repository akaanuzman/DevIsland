#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(python3 scripts/version.py version)"
: "${DEV_ISLAND_SIGN_IDENTITY:?Set your Developer ID Application identity.}"
: "${DEV_ISLAND_NOTARY_PROFILE:?Set a notarytool keychain profile.}"
if [[ "$DEV_ISLAND_SIGN_IDENTITY" != "Developer ID Application:"* ]]; then echo "A Developer ID Application identity is required." >&2; exit 1; fi
notary_args=(--keychain-profile "$DEV_ISLAND_NOTARY_PROFILE")
if [ -n "${DEV_ISLAND_NOTARY_KEYCHAIN:-}" ]; then notary_args+=(--keychain "$DEV_ISLAND_NOTARY_KEYCHAIN"); fi
bash scripts/build-app.sh
xcrun notarytool submit dist/Dev-Island-${version}-arm64.zip "${notary_args[@]}" --wait
xcrun stapler staple "dist/Dev Island.app"
xcrun stapler validate "dist/Dev Island.app"
spctl --assess --type execute --verbose=2 "dist/Dev Island.app"
bash scripts/package-dmg.sh
codesign --force --timestamp --sign "$DEV_ISLAND_SIGN_IDENTITY" dist/Dev-Island-${version}-arm64.dmg
xcrun notarytool submit dist/Dev-Island-${version}-arm64.dmg "${notary_args[@]}" --wait
xcrun stapler staple dist/Dev-Island-${version}-arm64.dmg
xcrun stapler validate dist/Dev-Island-${version}-arm64.dmg
ditto -c -k --sequesterRsrc --keepParent "dist/Dev Island.app" dist/Dev-Island-${version}-arm64.zip
