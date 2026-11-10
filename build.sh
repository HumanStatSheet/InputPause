#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
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
cp README.md LICENSE "$app/Contents/Resources/"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - --options runtime "$app"
codesign --verify --strict --verbose=2 "$app"
printf 'Release app: %s\n' "$app"
