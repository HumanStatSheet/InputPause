#!/bin/bash
# Rebuild, package and verify locally; no signing account or network required.
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid release version\n' >&2; exit 1; }
name="InputPause-${version}-arm64"
out="$PWD/dist"
mkdir -p "$out"
work=$(mktemp -d "${TMPDIR:-/tmp}/inputpause-package.XXXXXX")
mounted=0
cleanup() {
    if [[ "$mounted" == 1 ]]; then hdiutil detach "$work/mount"; fi
    rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/payload" "$work/mount" "$work/unzip" "$work/source/InputPause-${version}-source"
ditto --norsrc --noextattr build/InputPause.app "$work/payload/InputPause.app"
ln -s /Applications "$work/payload/Applications"
cp README.md LICENSE "$work/payload/"
codesign --verify --strict --verbose=2 "$work/payload/InputPause.app"
hdiutil create -ov -format UDZO -fs HFS+ -volname "InputPause ${version}" -srcfolder "$work/payload" "$out/$name.dmg"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$work/payload/InputPause.app" "$out/$name.zip"
# Explicit allowlist: never ship logs, SSH files, local paths or build caches.
for file in App.swift PauseState.swift Main.swift Tests.swift UISmoke.swift Info.plist build.sh package.sh README.md TESTING.md LICENSE .gitignore; do
    cp "$file" "$work/source/InputPause-${version}-source/"
done
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$work/source/InputPause-${version}-source" "$out/InputPause-${version}-source.zip"
hdiutil verify "$out/$name.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$out/$name.dmg"
mounted=1
test "$(readlink "$work/mount/Applications")" = /Applications
test -f "$work/mount/README.md"
test -f "$work/mount/LICENSE"
codesign --verify --strict --verbose=2 "$work/mount/InputPause.app"
diff -rq build/InputPause.app "$work/mount/InputPause.app"
printf 'PASS mounted DMG app matches build; Applications link and documents present\n'
hdiutil detach "$work/mount"
mounted=0
ditto -x -k "$out/$name.zip" "$work/unzip"
codesign --verify --strict --verbose=2 "$work/unzip/InputPause.app"
diff -rq build/InputPause.app "$work/unzip/InputPause.app"
printf 'PASS extracted ZIP app matches build\n'
(cd "$out" && shasum -a 256 "$name.dmg" "$name.zip" "InputPause-${version}-source.zip" > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
printf 'Release packages: %s\n' "$out"
