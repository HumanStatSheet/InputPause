# Verification record

Build environment: macOS 26.5.1 (25F80), Apple Swift 6.3.3, arm64 (verified over SSH).

## Current extension: verified test-first results

- Added full-input pointer filtering test. Initial compile-time missing `mode` interface; after adding mode storage but retaining keyboard-only filtering, real runtime RED: `FAIL: full-input mode suppresses CGEventType(rawValue: 1)`. Implemented filtering; GREEN.
- Added exact mask checks, all 15/30/60 deadline boundaries and both-mode tap-disabled cancellation. Compile-time RED for missing `eventMask`; implemented shared event types/mask; GREEN.
- Added emergency hold tests. Compile-time RED for missing `checkEmergency`, then real runtime RED with empty implementation: `FAIL: both shifts held two seconds unlock`. Implemented two-second hold, reset on release/new pause, cancellation; GREEN.
- Added full-input UI disable test. Real runtime RED: `FAIL: full-input Unlock Now is not clickable`; fixed button behavior; GREEN.
- Added mode/default/warning and both-mode lifecycle checks. Compile-time missing UI properties; implemented UI and lifecycle control reset; AppKit smoke GREEN.
- Added emergency callback/timer integration test. Missing `shiftKeysDown` compile-time RED, then real runtime RED: `FAIL: UI timer unlocks held shifts without more events`. Local implementation now connects per-side HID-state sampling to `filter`, also called by the timer. **Final GREEN confirmed on the lab Mac:** emergency timer/callback adapter assertions passed in both modes, followed by successful optimized release build and strict ad-hoc signature verification.

Last successful deterministic policy output:

```
PASS deadline/start tests
PASS keyboard-only callback filtering tests
PASS full-input pointer types and deadline recovery
PASS exact masks, all durations, both-mode disabled recovery
PASS disabled-tap fail-open tests
PASS duration validation tests
PASS both-mode opposite Shift hold, release, duplicate and cancellation
```

The final AppKit smoke covers layout, explicit mode/default, warnings, pointer-mode button behavior, countdown/lifecycle recovery, callback disabled/expiry behavior and the emergency callback/timer adapter. Tests create no real event tap and request no permissions.

## Native key-state investigation

Read the installed SDK's `CoreGraphics.framework/Headers/CGEventSource.h` and `CGEventTypes.h`. Apple documents HID system state as the combined hardware-source table and `CGEventSourceKeyState` as current per-key down/up state. The implementation queries fixed left/right Shift virtual keycodes 56 and 60. No shared modifier-bit inference, event-content capture or duplicate-event toggling. Remote-control software can use separate event sources; Screen Sharing physical-side behavior has not been verified.

## Release verification

The user explicitly approved source transfer, build/tests, local replacement and DMG/ZIP creation. All seven policy test groups and the final AppKit smoke passed. No input blocking or permission prompts were activated by the build. No public publishing was performed.

Release 1.1.0 (build 2) was compiled for arm64/macOS 13+ on the lab Mac. Strict codesign verification passed for the build, installed app, read-only mounted DMG app and ZIP-extracted app. Bundle comparison found no differences. The DMG checksum verified; its Applications symlink targets `/Applications`, README/license are present, and the volume was successfully ejected. All three archive SHA-256 checks passed.

Historical installed-build verification (before the documentation-only repack): executable SHA-256: `063537005e1d74439d08d8e67e9c5d201fd89c2eafaae0e123372e657cac2240` (matched build). Ad-hoc CDHash: `d325baa59491ffb473187a0c0b9af20114a30ad6`; identifier `local.inputpause.app`, no TeamIdentifier. The installed app was launched without activating Start; exact process executable matched the per-user Applications bundle. Idle/no-tap startup is covered by non-actuating smoke and code inspection, not a live privileged event-tap enumeration. The prior app backup has since been moved to Trash; it is not in the source or release payloads.

The package script rebuilds and verifies all archives. Release source contains only allowlisted source/scripts/docs, not operational logs. Browser-download quarantine/Gatekeeper first-open remains untested. Ad-hoc signing is not Apple notarization.

## Acceptance limits

The user previously confirmed real keyboard suppression and automatic countdown unlock for the original release, and subsequently reported physical full-input suppression and the opposite-Shift emergency shortcut as “Working great now.” These are user-reported attended results, not instrumented full-input testing. A stale ad-hoc Accessibility authorization was resolved by removing the old InputPause entry and re-adding the current app in System Settings; this is a reported workaround, not an automated TCC test.

Screen Sharing side-specific Shift behavior, all duration/mode combinations, real tap-disabled notifications, sleep/session transitions and force-quit recovery remain unverified attended acceptance cases. Synthetic tests neither create a real tap nor prove physical recovery. See README for short 15-second test instructions.

The final documentation/package refresh does not replace, restart or modify the working installed app or its privacy permissions. Package verification compares against the fresh build, not the historically installed bundle (whose embedded README differs). No publishing or GitHub authentication is part of this preparation.
