#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Full Xcode is required; do not silently ship a static icon fallback.
xcrun --find actool >/dev/null
xcodebuild -checkFirstLaunchStatus
mkdir -p build
swiftc -swift-version 5 -warnings-as-errors -parse-as-library PauseState.swift Tests.swift -o build/tests
./build/tests
swiftc -swift-version 5 -warnings-as-errors -parse-as-library PauseState.swift App.swift UISmoke.swift -o build/ui-smoke
./build/ui-smoke
app="$PWD/build/InputPause.app"
mkdir -p "$app/Contents/MacOS"
swiftc -swift-version 5 -warnings-as-errors -O -target arm64-apple-macosx13.0 -parse-as-library PauseState.swift App.swift Main.swift -o "$app/Contents/MacOS/InputPause"
cp Info.plist "$app/Contents/Info.plist"
mkdir -p "$app/Contents/Resources"
swiftc -swift-version 5 -warnings-as-errors Icon.swift -o build/draw-icon
./build/draw-icon build/InputPause.iconset
./build/draw-icon build/InputPause-dark.iconset dark
mkdir -p build/InputPause.icon/Assets
cp InputPause.icon/icon.json build/InputPause.icon/
cp build/InputPause.iconset/icon_512x512@2x.png build/InputPause.icon/Assets/key-light.png
cp build/InputPause-dark.iconset/icon_512x512@2x.png build/InputPause.icon/Assets/key-dark.png
# A stale build-7 standalone dark ICNS is not a native appearance mapping.
rm -f "$app/Contents/Resources/InputPause-dark.icns" "$app/Contents/Resources/Assets.car" "$app/Contents/Resources/InputPause.icns"
xcrun actool build/InputPause.icon --compile "$app/Contents/Resources" \
    --app-icon InputPause --platform macosx --target-device mac \
    --minimum-deployment-target 13.0 --output-partial-info-plist build/icon-info.plist \
    --errors --warnings --notices --output-format human-readable-text
# Merge Apple's emitted icon metadata before signing.
/usr/libexec/PlistBuddy -c 'Merge build/icon-info.plist' "$app/Contents/Info.plist"
test -s "$app/Contents/Resources/Assets.car"
test -s "$app/Contents/Resources/InputPause.icns"
xcrun assetutil --info "$app/Contents/Resources/Assets.car" > build/icon-assets.json
swiftc -swift-version 5 -warnings-as-errors -parse-as-library IconTests.swift -o build/icon-tests
./build/icon-tests
cp README.md LICENSE "$app/Contents/Resources/"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - --options runtime "$app"
codesign --verify --strict --verbose=2 "$app"
printf 'Release app: %s\n' "$app"
