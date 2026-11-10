# Verification record

Build environment: macOS 26.5.1 (25F80), Apple Swift 6.3.3, arm64 (verified over SSH).

## 1.1.1 — user-confirmed physical emergency fix

**Physical acceptance:** after installation of the 1.1.1 candidate, the user replied “It works now” following the requested physical-keyboard, keyboard-only, 15-second test of holding both Shift keys to unlock before timeout. This report is accepted as confirmation of the physical emergency fix and authorization to publish. It is not instrumented timing, a recorded diagnostic trace, or confirmation of every machine, mode, duration or Screen Sharing path. No redundant physical trial is required for publication.

**Historical 1.1.0 evidence:** the user reported both-Shift failure on both the lab Mac and the MacBook, despite working full-input suppression and countdown. The MacBook version **27.3 Beta (26C5035r)** is recorded exactly as reported, not independently queried. The prior broad success statement did not confirm the emergency chord. This is not established as a beta-only or Screen Sharing-only problem.

**Adapter dependency / test gap:** 1.1.0 ignores the delivered `flagsChanged` event's flags and polls `CGEventSource.keyState(.hidSystemState, key: 56/60)` instead, on every callback and timer tick. Synthetic tests injected `(true, true)`, bypassing the native source table entirely. They proved hold policy, not reliable physical detection. If that table disagrees with delivered modifier state, the hold never starts or is reset on a timer tick. We have not measured that disagreement on either physical keyboard, and have not established that consuming a session event causes HID state to stay false. Calling the polled table “upstream” did not prove this behavior.

**Official API evidence:** inspected Apple's installed SDK `CGEventSource.h`, `CGEventTypes.h`, and `IOKit/hidsystem/IOLLEvent.h`. `CGEventSourceKeyState` returns a source table's key state; Apple distinguishes the HID hardware-source table, combined-session table and private remote-control sources. This does not document exact update ordering relative to a consuming tap. The public IOKit header defines `NX_DEVICELSHIFTKEYMASK = 0x2` and `NX_DEVICERSHIFTKEYMASK = 0x4`; these are different from the combined Shift mask. Apple documents `CGEvent.flags` as the flags of the delivered Quartz event. References: [source-state tables](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid), [event flags](https://developer.apple.com/documentation/coregraphics/cgevent/flags). No private API or extra dependency was added.

**1.1.1 change:** consume side-specific modifier state from `flagsChanged` before returning nil. Retain only left/right booleans; callback and timer use the same `filter` and existing two-second policy. Timer does not overwrite delivered state with source-table polling. Releases replace state, duplicates do not toggle it, and `stop` clears it. Per-event monotonic deadlines, tap-disabled cancellation and the bounded timer remain intact. A missing modifier event/side flag can still affect detection; the user-confirmed physical result does not eliminate these general limitations.

**Test-first evidence on the lab:** a missing flags/time seam first caused a compile-time RED. With the seam present and original polling behavior unchanged, runtime RED was `FAIL: timer unlocks delivered side flags despite false HID key table`. The candidate then passed. This models a realistic source-table mismatch using delivered side flags and false polled keys; it is **not a captured physical reproduction or proof of root cause**. Both-mode adapter cases cover no-repeat timer completion, callback completion, single/shared/inconsistent flags, duplicate events, release reset, restart reset and countdown fallback. Existing policy/lifecycle tests remain in place. Boolean diagnostics separately failed at runtime (`FAIL: boolean diagnostic distinguishes event and source tables`) before implementation, then passed.

**Narrow diagnostic:** while active, the timer displays only latest left/right booleans for cached event state, HID keys, HID flags and combined-session flags. Last sample remains visible after unlock; idle does not poll. No characters, keycode events, coordinates, raw input flags, files, input history or telemetry are recorded. The source tables help compare separately labeled physical/remote trials but cannot conclusively identify event origin. No diagnostic trace was supplied with the successful user report; native source-table disagreement remains a hypothesis, not a measured root cause.

**Candidate build/package verification:** all policy groups and AppKit smoke passed on macOS 26.5.1 / Swift 6.3.3 with warnings-as-errors; optimized arm64/macOS 13+ build and plist validation passed. Strict ad-hoc codesign passed for the build, read-only mounted DMG app and extracted ZIP app. Both packaged bundles matched the build, the Applications link was verified, and the DMG was detached. Transferred archive checksums and source-ZIP allowlist bytes were checked locally. Candidate artifacts are kept separate from 1.1.0 releases. This validates packaging, not physical emergency behavior.

**Remaining acceptance:** full-input emergency recovery, separate machine coverage, Screen Sharing, and the complete single-key/release-reset matrix remain unverified physically. Synthetic coverage is separate from the accepted keyboard-only user report. The candidate was installed with authorization before that report. Publication only refreshes release documentation/packages; it does not replace the working installed app, change TCC permissions or create another installed backup. Original 1.1.0 assets remain unchanged.

## Historical 1.1.0 extension: verified test-first results

- Added full-input pointer filtering test. Initial compile-time missing `mode` interface; after adding mode storage but retaining keyboard-only filtering, real runtime RED: `FAIL: full-input mode suppresses CGEventType(rawValue: 1)`. Implemented filtering; GREEN.
- Added exact mask checks, all 15/30/60 deadline boundaries and both-mode tap-disabled cancellation. Compile-time RED for missing `eventMask`; implemented shared event types/mask; GREEN.
- Added emergency hold tests. Compile-time RED for missing `checkEmergency`, then real runtime RED with empty implementation: `FAIL: both shifts held two seconds unlock`. Implemented two-second hold, reset on release/new pause, cancellation; GREEN.
- Added full-input UI disable test. Real runtime RED: `FAIL: full-input Unlock Now is not clickable`; fixed button behavior; GREEN.
- Added mode/default/warning and both-mode lifecycle checks. Compile-time missing UI properties; implemented UI and lifecycle control reset; AppKit smoke GREEN.
- Added emergency callback/timer integration test. Missing `shiftKeysDown` compile-time RED, then real runtime RED: `FAIL: UI timer unlocks held shifts without more events`. The historical 1.1.0 implementation connected per-side HID-state sampling to `filter`, also called by the timer. **Final GREEN confirmed on the lab Mac:** emergency timer/callback adapter assertions passed in both modes, followed by successful optimized release build and strict ad-hoc signature verification.

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

## Historical 1.1.0 native key-state investigation

Read the installed SDK's `CoreGraphics.framework/Headers/CGEventSource.h` and `CGEventTypes.h`. Apple documents HID system state as the combined hardware-source table and `CGEventSourceKeyState` as current per-key down/up state. The implementation queries fixed left/right Shift virtual keycodes 56 and 60. No shared modifier-bit inference, event-content capture or duplicate-event toggling. Remote-control software can use separate event sources; Screen Sharing physical-side behavior has not been verified.

## Historical 1.1.0 release verification

The user explicitly approved source transfer, build/tests, local replacement and DMG/ZIP creation. All seven policy test groups and the final AppKit smoke passed. No input blocking or permission prompts were activated by the build. No public publishing was performed.

Release 1.1.0 (build 2) was compiled for arm64/macOS 13+ on the lab Mac. Strict codesign verification passed for the build, installed app, read-only mounted DMG app and ZIP-extracted app. Bundle comparison found no differences. The DMG checksum verified; its Applications symlink targets `/Applications`, README/license are present, and the volume was successfully ejected. All three archive SHA-256 checks passed.

Historical installed-build verification (before the documentation-only repack): executable SHA-256: `063537005e1d74439d08d8e67e9c5d201fd89c2eafaae0e123372e657cac2240` (matched build). Ad-hoc CDHash: `d325baa59491ffb473187a0c0b9af20114a30ad6`; identifier `local.inputpause.app`, no TeamIdentifier. The installed app was launched without activating Start; exact process executable matched the per-user Applications bundle. Idle/no-tap startup is covered by non-actuating smoke and code inspection, not a live privileged event-tap enumeration. The prior app backup has since been moved to Trash; it is not in the source or release payloads.

The package script rebuilds and verifies all archives. Release source contains only allowlisted source/scripts/docs, not operational logs. Browser-download quarantine/Gatekeeper first-open remains untested. Ad-hoc signing is not Apple notarization.

## Downloaded-release user report

The user reports that the GitHub release works perfectly on their MacBook running **27.3 Beta (26C5035r)** (version/build recorded exactly as reported, not independently queried). This confirms a successful user-reported downloaded-release installation/use, not an instrumented Gatekeeper test or verification of every recovery scenario. The exact first-open approval steps were not recorded.

## Acceptance limits

The user previously confirmed real keyboard suppression and automatic countdown unlock for the original release, and subsequently reported the app as “Working great now.” The user then clarified that the 1.1.0 opposite-Shift emergency shortcut fails on both machines; the earlier statement did not establish shortcut acceptance. These are user-reported attended results, not instrumented full-input testing. A stale ad-hoc Accessibility authorization was resolved by removing the old InputPause entry and re-adding the current app in System Settings; this is a reported workaround, not an automated TCC test.

Screen Sharing side-specific Shift behavior, all duration/mode combinations, real tap-disabled notifications, sleep/session transitions and force-quit recovery remain unverified attended acceptance cases. Synthetic tests neither create a real tap nor prove physical recovery. See README for short 15-second test instructions.

The final documentation/package refresh does not replace, restart or modify the working installed app or its privacy permissions. Package verification compares against the fresh build, not the historically installed bundle (whose embedded README differs). The 1.1.1 publication follows explicit user authorization after physical acceptance.
