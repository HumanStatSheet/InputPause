# Verification record

Current build-8 environment: macOS 26.7.3 (25G342), Xcode 27.2 (27B52), Apple Swift 6.4.2, arm64 (verified over SSH). Earlier build evidence below used macOS 26.5.1 / Swift 6.3.3.

## 1.1.2 — UI and permission recovery

Removed the production Shift diagnostic row and its diagnostic-only source-table queries. The delivered-side flags, cached booleans, emergency hold policy, callback and timer recovery remain unchanged. Replaced version/test-history warning text with concise emergency instructions and the full-input/remote countdown caveat. The diagnostic evidence below is historical, not current UI behavior.

Test-first lab execution in an isolated source directory produced runtime REDs for `production UI has no Shift diagnostic row`, `concise recovery guidance without test history`, `cancel reset unlocks without resetting or prompting`, and `separate explicit reset button is connected`, followed by GREEN. AppKit smoke and all seven policy groups passed with warnings-as-errors. Existing both-mode delivered-side flags, no-repeat timer, release, duplicates, restart and countdown cases still pass. Diagnostic-only injection/assertions were removed with the polling they tested.

Recovery tests inject confirmation, reset execution, permission requests and trust checks: cancel unlocks without a reset/prompt; nonzero exit and launch failure display errors; success requests permission without starting a pause; activation rechecks denied/approved trust. The production reset is exactly `/usr/bin/tccutil reset Accessibility local.inputpause.app` via Foundation Process, without shell, sudo or global reset. Confirmation explains that all copies with the same bundle ID are affected. Start retains its existing real trust check. Automated tests exercise no real TCC reset, permission prompt, event tap or input lock. The user subsequently confirmed physical reset recovery in candidate build 4; that report is not an automated result.

### Build 5 — single Accessibility button

Replaced the two permission buttons with one **Accessibility** button and no extra helper row. Trusted access opens Accessibility settings without a request or reset. Untrusted access offers Request Access, Reset & Request Access…, or Cancel; reset reuses the existing scoped reset and explicit confirmation. Input filtering and recovery logic are unchanged.

Test-first lab execution: runtime RED `single Accessibility button is connected`, then GREEN. Flow tests first produced compile-time REDs for missing settings/choice seams, then GREEN for trusted settings-only navigation, fresh normal request, dialog cancellation, reset confirmation cancellation, nonzero reset exit, reset launch failure and successful reset/request. All seven policy groups and the full non-actuating AppKit smoke passed with warnings-as-errors. Permission and settings side effects are injected; no real reset, prompt, settings navigation or input suppression was performed during this update.

Installed candidate 1.1.2 build 5 at `~/Applications/InputPause.app`, moved build 4 to `~/.Trash/InputPause-1.1.2-build4.app` without overwriting the earlier Trash copy, and launched without Start. Strict codesign verification and full build/installed bundle comparison passed. Ad-hoc identifier: `local.inputpause.app`; no TeamIdentifier; CDHash: `da4719280d634c61a715e96cc027747d901c3cef`. Matching executable SHA-256: `b19369870c6739ed814863dab310624a14e007104ec473505d303ebbeb16b1b2`. No packaging or publication; single-button UI acceptance remains with the user.

### Build 6 — native layout recovery

Preserved both the accepted build-5 source snapshot and the interrupted redesign before repairing the layout rather than reverting input/permission functionality. The window is now 440 × 420 points with native grouped settings, rounded system buttons, semantic colors, system typography, accessible control names, concise ready status, and no diagnostic UI. At build 6 the footer retained the no-recording/security caveat; build 7 removes it from the window while retaining the documentation.

Recovery test-first execution on the lab Mac produced runtime REDs for the compact window bound and concise approved-trust status, followed by GREEN. `bash build.sh` passed all seven policy groups and the complete non-actuating AppKit smoke with warnings-as-errors, then built and strictly verified the arm64 ad-hoc app. Layout assertions cover light, dark, both high-contrast appearances, both input modes and all three durations. Six app-only AppKit PNG renders cover idle and simulated active states in light/dark; these are view renders, not evidence of actual input suppression. Each idle preview resets to the 15-second launch default.

InputGate, PauseState, Start/Unlock/countdown lifecycle, delivered-side Shift handling, and the confirmed scoped reset flow are preserved; only UI construction and the approved-trust display string changed from the build-5 snapshot. No remote Start, event tap, TCC reset, permission prompt, or physical recovery test was performed. Historical physical acceptance below is not a claim of new build-6 physical testing. The user subsequently approved the redesign and authorized publication after the final footer/icon changes.

### Build 7 — release icon and final UI polish

Removed the visible “No input recording. Not a security lock.” footer, retaining those limitations in README. Runtime RED `privacy and security disclaimer stays in README, not the window` preceded the removal; the full AppKit smoke then passed. No input, countdown, emergency or permission-flow code changed from build 6.

Added original vector artwork in `Icon.swift`: a white sculpted keyboard key with a red pause symbol, generated with native AppKit and packaged by `iconutil`. The icon resource test first failed on the missing bundle declaration. A subsequent transparent-corner failure exposed unscaled device-space shadow lengths at small sizes; scaling those lengths fixed the failure. GREEN validates the ICNS declaration/load, ten standard/Retina PNG dimensions (16–1024 pixels), white face, red symbol and transparent corners. `Icon.swift` and `IconTests.swift` are included in the source archive, and the build generates the bundled ICNS without new dependencies.

Seven deterministic policy groups, delivered-side Shift adapter checks, injected permission-flow/lifecycle checks, and light/dark/high-contrast layout checks passed on the lab Mac. Six app-only view renders cover idle and simulated active states in light/dark. These tests never request permissions, reset TCC, create an event tap or suppress real input. The user approved the previous redesign and explicitly authorized build-7 idle installation and experimental publication. No new physical-input acceptance is claimed; historical user-confirmed countdown/Shift and reset recovery remain separately scoped below and above. Ad-hoc signing still provides no Developer ID identity continuity or notarization, and renewed Accessibility approval may be needed after replacement.

After the user requested matching dark artwork, a focused runtime RED confirmed the dark ICNS was absent. `Icon.swift` now also generates a charcoal key with a red pause symbol. GREEN checks both readable ICNS files and twenty standard/Retina PNGs; the key-face sample was moved clear of red-bar antialiasing at 16 pixels. The default white icon, main-window colors and all application behavior are unchanged. Apple’s Icon Composer documentation describes appearance-aware icons, but `xcrun --find actool` and `xcrun --find icontool` both failed in the Command Line Tools-only lab; `iconutil` is available. This release includes the dark resource but does not claim automatic appearance switching. No tools were installed and no runtime workaround was added.

The release packaging workflow verifies signatures and full bundle equality for the build, mounted DMG and extracted app ZIP, plus archive checksums. Publication additionally compares every source-archive member with the committed GitHub source and downloads all assets to verify their hashes. Installed-app verification and app-only screenshots are recorded separately from synthetic previews; idle launch does not establish physical recovery or quarantined first-open behavior.

### Build 8 — native automatic icon appearance

Full Xcode is now available and its first-launch check passes; no agreements were accepted by automation. A resource-test runtime RED (`compiled native appearance catalog exists`) preceded integration of the Icon Composer document, `actool` compilation, emitted Info.plist metadata and compiled-catalog tests. The build fails rather than silently shipping static artwork if the compiler or native catalog is absent. `assetutil` confirms Aqua → white-key and DarkAqua → charcoal-key layer records. Both retain red pause marks. The unused standalone dark ICNS is removed from the app; the generated white ICNS remains for older macOS.

Seven policy groups, the complete non-actuating AppKit smoke and twenty source-image resource checks passed with warnings-as-errors. App.swift, PauseState.swift, Main.swift and their existing policy/UI tests are unchanged from build 7. No tap, suppression, reset, permission request or physical recovery trial was performed.

**Native selection acceptance:** the compiled, signed build-8 bundle was rendered by the public `NSWorkspace.shared.icon(forFile:)` API in fresh probe processes while the real OS appearance changed light → dark → light with automatic icon style. Measured key-face RGB changed from approximately 0.988/0.988/0.988 to 0.224/0.224/0.224 and back; the pause stayed red. The read-only `NativeIconSelectionTests.swift` checks those pixels and writes the actual OS-selected icon PNG. This is not merely `ictool` preview selection or loading the individual artwork files. Changing a probe’s NSAppearance alone does not select the global icon style. A prior bundle path cached build-7 artwork; acceptance used a fresh bundle copy instead of treating that false result as success.

The separate, non-shipping lab driver temporarily operated the OS appearance configuration through SkyLight’s private settings interfaces (also used by System Settings), then restored and read back the original dark window appearance and dark icon style. Those diagnostic setters are **not** in the source archive, app, build or package scripts. The delivered app uses no private API, persistent appearance observer, runtime icon override or signed-bundle mutation. The public probe is read-only and can be reproduced after manual changes in System Settings:

```sh
swiftc -swift-version 5 -warnings-as-errors -parse-as-library NativeIconSelectionTests.swift -o build/native-icon-tests
# Select automatic dark icon style and Light system appearance, then:
./build/native-icon-tests /path/to/InputPause.app light build/native-light.png
# Select Dark system appearance, then:
./build/native-icon-tests /path/to/InputPause.app dark build/native-dark.png
```

Screen-capture preflight returned false; no capture request or permission prompt was made. Evidence images are OS-selected icon renders and AppKit view renders, **not live Finder/Dock screenshots**. Apple’s Icon Composer Default/Dark previews were separately inspected. Older macOS fallback and Clear/Tinted style behavior are not claimed as automatic custom light/dark switching. Quarantined first-open and new physical-input behavior remain untested.

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

The historical 1.1.1 documentation/package refresh did not replace, restart or modify the working installed app or its privacy permissions. Package verification compares against the fresh build, not the historically installed bundle (whose embedded README differs). The 1.1.1 publication follows explicit user authorization after physical acceptance.
