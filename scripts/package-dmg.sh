#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(python3 scripts/version.py version)"
test -d "dist/Dev Island.app"
rm -rf .build/dmg
mkdir -p .build/dmg
ditto "dist/Dev Island.app" ".build/dmg/Dev Island.app"
if [ ! -L .build/dmg/Applications ]; then ln -s /Applications .build/dmg/Applications; fi
hdiutil create -volname "Dev Island" -srcfolder .build/dmg -ov -format UDZO dist/Dev-Island-${version}-arm64.dmg
