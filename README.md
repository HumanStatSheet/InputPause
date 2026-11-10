# InputPause

A small native Swift/AppKit input-cleaning utility for Apple Silicon Macs (macOS 13+). No third-party dependencies. Locally ad-hoc signed; not notarized.

## Experimental project and maintenance

**Experimental, fully vibe-coded / AI-assisted software.** The implementation and documentation were produced with AI assistance; passing automated checks and a successful user trial are not a guarantee of safety or reliability. This utility temporarily suppresses input: use it attended, with a short countdown, and understand the recovery limits below.

Maintenance will be sparse; timely fixes, support and future macOS compatibility are not promised. Forks and independent improvements are encouraged. The project remains available under the **MIT license**; see `LICENSE` for its terms and warranty disclaimer.

## Install release 1.1.0

Apple Silicon only, macOS 13 or later (tested on macOS 26.5.1). Verify the downloads with `shasum -a 256 -c SHA256SUMS` in the directory containing all three archives. Open `InputPause-1.1.0-arm64.dmg` and drag **InputPause.app** onto **Applications**, then eject the disk. Alternatively extract `InputPause-1.1.0-arm64.zip` and move the app to Applications (or `~/Applications` for a per-user install). Quit an older copy before replacing it.

This release is **ad-hoc signed, not Developer ID signed and not Apple notarized**. Its signature checks bundle integrity, not a verified publisher identity. A browser-downloaded copy may be blocked by Gatekeeper. Only if you trust and have inspected this release, use Apple's per-app **Privacy & Security → Open Anyway** flow if offered, or build from the provided source. Never disable Gatekeeper globally. Quarantined browser-download/first-open behavior has not been tested; local installation does not establish that it passes Gatekeeper.

## Use (attended)

1. Open `~/Applications/InputPause.app`. Launch is idle: no event tap or permission request.
2. If needed, click **Enable Accessibility…**, read the explanation, and approve **InputPause** in System Settings → Privacy & Security → Accessibility. Never grant Terminal or SSH Accessibility for this app. If macOS requests Input Monitoring, approve InputPause only. Errors identify the failed API.
3. Choose **Keyboard only** (default) or explicitly choose **Keyboard + mouse/trackpad**. Choose **15 seconds** (default), **30 seconds**, or **60 seconds**. Release all keys, modifiers and buttons. Click **Start Timed Pause** yourself.
4. Keyboard-only mode leaves the pointer and **Unlock Now** usable. Full-input mode suppresses keyboard events plus mouse/trackpad button presses/releases, movement, dragging and scrolling. **Unlock Now is not clickable while full-input mode is active. Wait for the countdown or use the emergency shortcut.** The existing pause cannot be extended by Start.
5. Emergency exit in either mode: hold **LEFT SHIFT + RIGHT SHIFT together for about 2 seconds on the Mac’s physical keyboard**. Releasing either resets the hold. Release both after unlocking. Screen Sharing may not transmit distinct physical Shift states; do not rely on this shortcut from a remote-control client. The countdown remains mandatory and independent of the shortcut.

**Limitations:** not a security lock. Media/Fn/power keys, protected shortcuts, secure-input contexts, alternate input APIs, trackpad gestures outside ordinary pointer/scroll events and Screen Sharing input may behave differently. Do not apply liquid directly to equipment. Power down when every hardware function must be inactive. If a modifier/button seems stuck afterward, press and release it. Physical suppression and recovery need attended testing; automated checks do not prove them.

## Fail-open design

- `mach_continuous_time()` includes elapsed sleep time. Every callback checks its deadline independently of UI updates.
- A common-mode 0.1-second timer updates the countdown, samples the emergency shortcut even without repeated events, and removes expired/disabled taps.
- Either tap-disabled notification cancels; the app never automatically re-enables it.
- Manual unlock, screen/system sleep, session resignation, window close and normal quit clear state and invalidate the tap. Wake/relaunch never resumes a pause.
- Emergency detection queries `CGEventSource.keyState(.hidSystemState, key: 56/60)` separately for left/right Shift. This hardware-source state is upstream of the session tap, not the shared Shift modifier bit. Repeated events cannot toggle state. Only the hold-start timestamp is retained, not event contents. Remote-control sources may not appear in HID state.
- Process exit removes its event tap at OS level. A blocked callback is subject to the macOS event-tap watchdog, not a hard real-time guarantee. Real force-quit recovery remains an attended acceptance check.

## Privacy

The filter examines event **types only**, never characters, text, coordinates, button payloads or event keycodes. It additionally queries only the current physical left/right Shift down states during an active pause for emergency exit. No input recording/logging, networking, analytics, updater, login item, helper daemon, saved settings or automatic launch. The app creates no user data files. macOS independently maintains its permission metadata and diagnostics. Launch never requests permissions or installs a tap.

## Build and tests

With Apple's Command Line Tools on the Mac:

```sh
cd /path/to/InputPause
bash build.sh
```

Runs deterministic policy tests and a non-actuating AppKit smoke executable, builds an optimized arm64 release with warnings-as-errors, and verifies plist/ad-hoc signature. Tests use synthetic event types and in-memory state; no event injection, real tap creation, `InputGate.start`, or TCC changes. The emergency adapter test supplies synthetic Shift states; it is not a physical-key acceptance test.

Artifacts: `build/InputPause.app`, `build/tests`, `build/ui-smoke`. Installed location: `~/Applications/InputPause.app`. Quit before replacement. No package manager or dependencies.

### Reproduce the packages from source

Extract `InputPause-1.1.0-source.zip`, enter the extracted source directory, and run:

```sh
bash package.sh
```

This reruns both test executables, compiles/signs the release, and writes versioned DMG, app ZIP, source ZIP and `SHA256SUMS` under `dist/`. It verifies the read-only mounted DMG and extracted ZIP signatures and compares their apps with the build, then unmounts the DMG. The DMG includes an Applications link, README and license. The source archive uses an explicit file allowlist; no credentials, build logs or machine configuration are included. Only Apple Command Line Tools and macOS built-in utilities are required. Run from a logged-in GUI session for AppKit smoke tests. The workflow is reproducible, but archive bytes are not promised identical across runs: filesystem/archive timestamps and toolchain versions may differ.

Files: `.gitignore`, `PauseState.swift`, `App.swift`, `Main.swift`, `Tests.swift`, `UISmoke.swift`, `Info.plist`, `build.sh`, `package.sh`, `README.md`, `LICENSE`, `TESTING.md`.

## Reported use and Accessibility troubleshooting

The user reported that physical full-input suppression and the opposite-Shift emergency shortcut were “Working great now.” This is a user-reported attended success, not an instrumented acceptance test or proof of every recovery path. See `TESTING.md` for the distinction from automated coverage.

After an ad-hoc-signed app replacement, an existing Accessibility entry may appear enabled but no longer authorize the new copy. In the reported local trial, removing the old **InputPause** entry from System Settings → Privacy & Security → Accessibility and adding the current app again resolved the permission problem. Approve only the intended app; do not reset the entire privacy database or grant SSH/Terminal access. Rebuilding/replacing an ad-hoc app can require renewed consent; avoid replacing a working installed copy merely to update release documents.

## Attended acceptance

From Screen Sharing, select **Keyboard + mouse/trackpad**, keep **15 seconds**, and click **Start Timed Pause**. Try movement, click, drag and scroll in a harmless window; verify input returns automatically. Do not assume remote input follows the physical path or that the remote Shift shortcut works. Never depend on clicking Unlock during this test.

At the physical Mac, test each Shift alone (must not unlock), both held for two seconds (must unlock), and releasing either before two seconds (must reset). Repeat in both modes. Separately test 30/60-second expiry, keyboard-only Unlock, sleep/wake, close/quit, force-quit recovery and special keys. No unattended full-input test is run during installation.

## Uninstall

Quit, delete `~/Applications/InputPause.app`, optionally delete your source checkout, and remove its Accessibility/Input Monitoring entries in System Settings. No background components or saved app settings need removal.
