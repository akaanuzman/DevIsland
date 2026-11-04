#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SPARKLE_PUBLIC_KEY:?Set the Sparkle public key}"
: "${SPARKLE_PRIVATE_KEY_FILE:?Set a private key file path}"
: "${DEV_ISLAND_SIGN_IDENTITY:?Set Developer ID identity}"
version="$(python3 scripts/version.py version)"
[ "${GITHUB_REF_NAME:-v$version}" = "v$version" ] || { echo "Tag must match Resources/version.json" >&2; exit 1; }
export DEV_ISLAND_OFFICIAL_RELEASE=1
bash scripts/notarize.sh
mkdir -p .build/feed
if [ -f .build/feed/appcast.xml ]; then cp .build/feed/appcast.xml .build/feed/previous.xml; else rm -f .build/feed/previous.xml; fi
archive="Dev-Island-${version}-arm64.dmg"
cp "dist/$archive" ".build/feed/$archive"
cp "docs/releases/$version.md" ".build/feed/${archive%.dmg}.md"
args=()
if [[ "$version" == *-beta.* ]]; then args+=(--channel beta); fi
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" --maximum-versions 0 --embed-release-notes \
  --download-url-prefix "https://github.com/akaanuzman/DevIsland-releases/releases/download/v${version}/" \
  "${args[@]}" .build/feed
python3 scripts/validate-appcast.py .build/feed/appcast.xml .build/feed/previous.xml
shasum -a 256 "dist/Dev-Island-${version}-arm64.dmg" "dist/Dev-Island-${version}-arm64.zip" > dist/SHA256SUMS
