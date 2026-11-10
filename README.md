# InputPause

## [Download InputPause — Releases](https://github.com/HumanStatSheet/InputPause/releases)

Find the latest downloads under **Assets** on the release page, including experimental prereleases.

A small native Swift/AppKit input-cleaning utility for Apple Silicon Macs (macOS 13+). No third-party dependencies. Locally ad-hoc signed; not notarized.

## Experimental project and maintenance

**Experimental, fully vibe-coded / AI-assisted software.** The implementation and documentation were produced with AI assistance; passing automated checks and a successful user trial are not a guarantee of safety or reliability. This utility temporarily suppresses input: use it attended, with a short countdown, and understand the recovery limits below.

Maintenance will be sparse; timely fixes, support and future macOS compatibility are not promised. Forks and independent improvements are encouraged. The project remains available under the **MIT license**; see `LICENSE` for its terms and warranty disclaimer.

## 1.1.3 experimental prerelease — auxiliary media controls (issue #1)

The event tap previously subscribed only to ordinary keyboard/modifier events (and optional pointer events), missing `NX_SYSDEFINED` auxiliary controls. Build 9 subscribes to those events in both modes and filters recognized volume, brightness, playback/seek, keyboard illumination, contrast, launch-panel and video-mirror controls while active. Automated delivered-event fixtures pass; physical suppression remains to be tested. It handles their press/repeat/release events without blocking unrelated system notifications. Power, eject and unknown auxiliary controls deliberately pass through. The existing session tap, both-Shift recovery, deadline checks, pointer modes, single Accessibility flow and native adaptive icon are preserved.

This fixes a demonstrated filtering gap, **not a physically verified Mission Control fix**. The issue reports an M1 MacBook Pro running “Golden Gate 27.2”; that version is reporter-supplied, not the lab OS. Mission Control behavior on the affected M1 remains unverified. **Power, Touch ID/lock and Fn/Globe suppression are not guaranteed.** These and other firmware-handled keys may take other paths. No blanket system-event filter, lower-level driver, elevated privilege or firmware-control claim is added. Issue #1 stays open pending attended testing on the affected keyboard. This experimental binary is published with explicit user authorization so it can be tested there; publication is not physical acceptance. Previous **1.1.2 assets remain unchanged and do not contain this fix**.

## 1.1.2 — native UI, app icon and explicit permission recovery

Build 8 preserves the user-approved compact native AppKit layout, system fonts and semantic colors, grouped mode/duration controls, a clear Start/countdown/Unlock area, and one Accessibility button. It adds an original white keyboard-key app icon with a red pause symbol and a charcoal-key Dark variant. Apple’s native Icon Composer catalog selects the artwork on macOS 26+; older systems use the generated white ICNS fallback. Privacy/security disclaimers stay in this README rather than the main window. Light/dark and high-contrast layouts are tested with simulated active state; no input tap is installed by the preview harness. The user confirmed reset recovery in candidate build 4 and approved the build-6 redesign. The diagnostic row and diagnostic-only source-table polling are removed; delivered-side Shift emergency detection is unchanged. **Accessibility** unlocks first. If access is already granted it opens Accessibility settings without resetting approval. Otherwise a compact dialog offers **Request Access**, **Reset & Request Access…**, or **Cancel**. Request Access uses the normal macOS permission prompt. Reset requires a separate explicit confirmation before running `/usr/bin/tccutil reset Accessibility local.inputpause.app`. This affects all copies sharing that bundle ID, not other apps. After success, approve InputPause again in System Settings, then click Start yourself. Cancellation makes no permission changes; failures are displayed without escalation.

Ad-hoc replacements can change the code identity even without a version change. This recovery option does not provide signing continuity; Developer ID signing is a separate future distribution decision. No global reset, shell, sudo, or weakened signing requirement is used.

## Released 1.1.1 — emergency Shift fix

The user confirmed the 1.1.1 physical-keyboard emergency fix after the requested keyboard-only, 15-second trial using both Shift keys to unlock before timeout. This is user-reported acceptance, not an instrumented test or verification of every mode, machine or remote path. Keep a short countdown as the independent recovery path. It reads side-specific Shift flags from delivered modifier events before suppressing them, instead of relying on the polled HID key table for emergency decisions. The native reason for the 1.1.0 failure is not yet established; see `TESTING.md`. No existing release assets have been replaced.

Technical diagnostic history is retained in `TESTING.md`, not in the production interface. Replacing an ad-hoc build may require re-adding InputPause in Accessibility.

## Download 1.1.3 (experimental prerelease)

**[Download InputPause 1.1.3 — release page](https://github.com/HumanStatSheet/InputPause/releases/tag/v1.1.3)** · **[Download the Apple Silicon DMG directly](https://github.com/HumanStatSheet/InputPause/releases/download/v1.1.3/InputPause-1.1.3-arm64.dmg)**

On the release page, expand **Assets** to find the DMG, ZIP alternatives, and checksums.

Apple Silicon only, macOS 13 or later (tested on macOS 26.7.3). Verify the downloads with `shasum -a 256 -c SHA256SUMS` in the directory containing all three archives. Open `InputPause-1.1.3-arm64.dmg` and drag **InputPause.app** onto **Applications**, then eject the disk. Alternatively extract `InputPause-1.1.3-arm64.zip` and move the app to Applications (or `~/Applications` for a per-user install). Quit an older copy before replacing it.

This release is **ad-hoc signed, not Developer ID signed and not Apple notarized**. Its signature checks bundle integrity, not a verified publisher identity. A browser-downloaded copy may be blocked by Gatekeeper. Only if you trust and have inspected this release, use Apple's per-app **Privacy & Security → Open Anyway** flow if offered, or build from the provided source. Never disable Gatekeeper globally. Quarantined browser-download/first-open behavior has not been tested; local installation does not establish that it passes Gatekeeper.

## Use (attended)

1. Open `~/Applications/InputPause.app`. Launch is idle: no event tap or permission request.
2. If needed, click **Accessibility**, read the explanation, and approve **InputPause** in System Settings → Privacy & Security → Accessibility. Never grant Terminal or SSH Accessibility for this app. If macOS requests Input Monitoring, approve InputPause only. Errors identify the failed API.
3. Choose **Keyboard only** (default) or explicitly choose **Keyboard + mouse/trackpad**. Choose **15 seconds** (default), **30 seconds**, or **60 seconds**. Release all keys, modifiers and buttons. Click **Start Timed Pause** yourself.
4. Keyboard-only mode leaves the pointer and **Unlock Now** usable. Full-input mode suppresses keyboard events plus mouse/trackpad button presses/releases, movement, dragging and scrolling. **Unlock Now is not clickable while full-input mode is active. Wait for the countdown.** The existing pause cannot be extended by Start.
5. Hold **LEFT SHIFT + RIGHT SHIFT together for about 2 seconds on the Mac’s physical keyboard** for emergency unlock. Releasing either resets the hold. Release both after unlocking. The physical keyboard-only fix was confirmed by the user in 1.1.1; remote behavior and other attended recovery cases remain unverified. Keep the independent countdown at 15 seconds for initial testing.

**Limitations:** not a security lock. Media/Fn/power keys, protected shortcuts, secure-input contexts, alternate input APIs, trackpad gestures outside ordinary pointer/scroll events and Screen Sharing input may behave differently. Do not apply liquid directly to equipment. Power down when every hardware function must be inactive. If a modifier/button seems stuck afterward, press and release it. Physical suppression and recovery need attended testing; automated checks do not prove them.

## Fail-open design

- `mach_continuous_time()` includes elapsed sleep time. Every callback checks its deadline independently of UI updates.
- A common-mode 0.1-second timer updates the countdown, samples the emergency shortcut even without repeated events, and removes expired/disabled taps.
- Either tap-disabled notification cancels; the app never automatically re-enables it.
- Manual unlock, screen/system sleep, session resignation, window close and normal quit clear state and invalidate the tap. Wake/relaunch never resumes a pause.
- Emergency detection decodes the public IOKit left/right Shift masks from `flagsChanged` event flags before consuming the event. Only two booleans and the hold timestamp are retained for detection. Callback and timer share `filter`; timer ticks reuse the delivered states until a modifier event updates them. Duplicate events do not toggle state. The shared Shift flag alone cannot establish both sides. No source-table polling is used. Missing side flags or missed releases remain physical acceptance risks; timeout is independent.
- Process exit removes its event tap at OS level. A blocked callback is subject to the macOS event-tap watchdog, not a hard real-time guarantee. Real force-quit recovery remains an attended acceptance check.

## Privacy

The filter examines event types, Shift modifier flags, and (only for active system-defined auxiliary controls) the subtype, control identifier and press/release encoding. It never reads characters, text, coordinates, ordinary keyboard keycodes or pointer-button payloads. No input recording. No input history, auxiliary payloads or raw flags are retained. No input logging, networking, analytics, updater, login item, helper daemon, saved settings or automatic launch. The app creates no user data files. macOS independently maintains its permission metadata and diagnostics. Launch never requests permissions or installs a tap.

## Build and tests

With full Apple Xcode (including macOS build support) on the Mac, after personally completing its license and first-launch setup. This release was built with Xcode 27.2 / Swift 6.4.2. Command Line Tools alone are not sufficient for `actool`. If necessary, select Xcode per build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` rather than changing system-wide tool selection:

```sh
cd /path/to/InputPause
bash build.sh
```

Runs deterministic policy tests and a non-actuating AppKit smoke executable, builds an optimized arm64 release with warnings-as-errors, and verifies plist/ad-hoc signature. Tests use synthetic event types and in-memory state. Auxiliary tests construct AppKit events, bridge them to Quartz and inject them into the production filter; **nothing is posted to the OS**. No real tap creation, `InputGate.start`, or TCC changes. The emergency adapter test supplies synthetic Shift states; neither it nor the media fixtures are physical-key acceptance tests.

The build compiles `Icon.swift` (original native AppKit vector artwork), renders ten standard/Retina PNGs at 16–1024 pixels for each variant, and populates the `InputPause.icon/icon.json` template into a complete `build/InputPause.icon` document. Apple’s `actool` compiles that document into `Assets.car` and the backward-compatible `InputPause.icns`; its emitted icon metadata is merged into Info.plist before signing. Resource tests inspect the actual catalog’s Aqua/DarkAqua artwork mappings, ICNS declaration/load, dimensions, colors and transparency. No graphics package or downloaded artwork is needed.

**Native icon appearance:** on macOS 26+, System Settings → Appearance → Icon & widget style controls icon appearance independently of window appearance. Select **Dark → Automatic** to follow light/dark system appearance, or **Dark → Always** for the charcoal key. Default keeps the white key; Clear/Tinted are system-generated styles and may change its colors. On older macOS, the white ICNS fallback is static. This uses [Apple’s native Icon Composer pipeline](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer), not two standalone ICNS files, a runtime observer, icon-image overrides, private app APIs or bundle mutation. The approved main-window semantic colors are unchanged. Native OS selection was verified through `NSWorkspace` under actual light → dark → light system appearance with automatic icon style; this is stronger than source preview exports, but not a live Dock screenshot. See `TESTING.md` for the verification method and limits.

Artifacts: `build/InputPause.app`, `build/tests`, `build/ui-smoke`, `build/icon-tests`, `build/InputPause.iconset`. Installed location: `~/Applications/InputPause.app`. Quit before replacement. No package manager or dependencies.

### Reproduce the packages from source

Extract the matching source ZIP (`InputPause-1.1.3-source.zip`), enter the extracted source directory, and run:

```sh
bash package.sh
```

This reruns policy, AppKit smoke and icon-resource tests, compiles/signs the release, and writes versioned DMG, app ZIP, source ZIP and `SHA256SUMS` under `dist/`. It verifies the read-only mounted DMG and extracted ZIP signatures and compares their apps with the build, then unmounts the DMG. The DMG includes an Applications link, README and license. The source archive uses an explicit file allowlist; no credentials, build logs or machine configuration are included. Only full Apple Xcode and macOS built-in utilities are required. Run from a logged-in GUI session for AppKit smoke tests. The workflow is reproducible, but archive bytes are not promised identical across runs: filesystem/archive timestamps and toolchain versions may differ.

Files: `.gitignore`, `PauseState.swift`, `App.swift`, `Main.swift`, `Tests.swift`, `UISmoke.swift`, `Icon.swift`, `IconTests.swift`, `NativeIconSelectionTests.swift`, `InputPause.icon/icon.json`, `Info.plist`, `build.sh`, `package.sh`, `README.md`, `LICENSE`, `TESTING.md`.

## Reported use and Accessibility troubleshooting

The 1.1.0 shortcut failed on both tested Macs despite reported working suppression and countdown recovery. The user subsequently confirmed that the 1.1.1 physical-keyboard fix works. Upgrade from 1.1.0; its original assets remain unchanged. See `TESTING.md` for the scope of this user report and remaining acceptance limits.

After an ad-hoc-signed app replacement, an existing Accessibility entry may appear enabled but no longer authorize the new copy. In the reported local trial, removing the old **InputPause** entry from System Settings → Privacy & Security → Accessibility and adding the current app again resolved the permission problem. Approve only the intended app; do not reset the entire privacy database or grant SSH/Terminal access. Rebuilding/replacing an ad-hoc app can require renewed consent; avoid replacing a working installed copy merely to update release documents.

## Attended acceptance

From Screen Sharing, select **Keyboard + mouse/trackpad**, keep **15 seconds**, and click **Start Timed Pause**. Try movement, click, drag and scroll in a harmless window; verify input returns automatically. Do not assume remote input follows the physical path or that the remote Shift shortcut works. Never depend on clicking Unlock during this test.

For additional attended checks, start with **keyboard-only, 15 seconds**, physically at the Mac. Test each Shift alone (must not unlock), both held for two seconds (must unlock), and releasing either before two seconds (must reset). If the shortcut fails, wait for the timer. Only then repeat in full-input mode. Test Screen Sharing separately and label the input path. Separately test 30/60-second expiry, keyboard-only Unlock, sleep/wake, close/quit, force-quit recovery and special keys. The user has confirmed the physical keyboard-only emergency fix; this broader checklist is not claimed complete. No unattended full-input test is run during installation.

## Uninstall

Quit, delete `~/Applications/InputPause.app`, optionally delete your source checkout, and remove its Accessibility/Input Monitoring entries in System Settings. No background components or saved app settings need removal.
