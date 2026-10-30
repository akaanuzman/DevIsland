#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
bash scripts/swift.sh build -c "$configuration" --arch arm64
binary_dir="$(bash scripts/swift.sh build -c "$configuration" --arch arm64 --show-bin-path)"
app="$PWD/dist/Dev Island.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources/en.lproj" "$app/Contents/Resources/tr.lproj"
cp "$binary_dir/DevIsland" "$app/Contents/MacOS/DevIsland"
cp "$binary_dir/dev-island-bridge" "$app/Contents/Helpers/dev-island-bridge"
cp Resources/Info.plist "$app/Contents/Info.plist"
python3 scripts/package-vscode-extension.py "$app/Contents/Resources/DevIslandVSCode.vsix"
cat > "$app/Contents/Resources/tr.lproj/InfoPlist.strings" <<'EOF'
"NSAppleEventsUsageDescription" = "Dev Island, Claude oturumuna ait Apple Terminal sekmesini seçebilir. İzin vermezsen yalnızca Terminal uygulamasını öne getirir.";
EOF
cat > "$app/Contents/Resources/en.lproj/InfoPlist.strings" <<'EOF'
"NSAppleEventsUsageDescription" = "Dev Island can select the Apple Terminal tab belonging to your Claude session. If you decline, it will only bring Terminal to the front.";
EOF
mkdir -p .build/icon.iconset
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swiftc Sources/DevIslandCore/BrandGeometry.swift scripts/make-icon.swift -o .build/make-icon
.build/make-icon "$PWD/.build/icon-1024.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" .build/icon-1024.png --out ".build/icon.iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" .build/icon-1024.png --out ".build/icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
python3 scripts/pack-icon.py .build/icon.iconset "$app/Contents/Resources/AppIcon.icns"
identity="${DEV_ISLAND_SIGN_IDENTITY:--}"
if [ "$identity" = "-" ]; then
    codesign --force --sign - "$app/Contents/Helpers/dev-island-bridge"
    codesign --force --sign - --entitlements Resources/DevIsland.entitlements "$app"
else
    codesign --force --options runtime --timestamp --sign "$identity" "$app/Contents/Helpers/dev-island-bridge"
    codesign --force --options runtime --timestamp --sign "$identity" --entitlements Resources/DevIsland.entitlements "$app"
fi
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/Dev-Island-0.3.6-arm64.zip
echo "Built: $app"
if [ "$identity" = "-" ]; then echo "Local ad-hoc signature. Developer ID signing and notarization are still required for public distribution."; fi
