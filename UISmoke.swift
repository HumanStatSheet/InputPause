import AppKit
import CoreGraphics

@main struct UISmoke {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        delegate.buildUI()
        let content = app.windows.first!.contentView!
        content.layoutSubtreeIfNeeded()
        func labels(in view: NSView) -> [String] {
            (view as? NSTextField).map { [$0.stringValue] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        expect(!labels(in: content).contains { $0.contains("No input recording") || $0.contains("Not a security lock") }, "privacy and security disclaimer stays in README, not the window")
        expect(!labels(in: content).contains { $0.contains("Shift diagnostic") || $0.contains("Shift L/R") }, "production UI has no Shift diagnostic row")
        expect(content.fittingSize.height <= content.bounds.height, "all controls fit without clipping")
        expect(content.bounds.width <= 440 && content.bounds.height <= 420, "compact native utility window without excess footer space")
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap { descendants($0) }
        }
        let settingsGroup = descendants(content).compactMap { $0 as? NSBox }.first
        expect(settingsGroup != nil && delegate.mode.isDescendant(of: settingsGroup!) && delegate.duration.isDescendant(of: settingsGroup!), "mode and duration share a native settings group")
        expect(delegate.startButton.bezelStyle == .rounded && delegate.unlockButton.bezelStyle == .rounded, "actions use native rounded buttons")
        expect(delegate.startButton.font == NSFont.systemFont(ofSize: 13, weight: .semibold), "primary action has native semibold emphasis without a keyboard shortcut")
        expect(delegate.startButton.keyEquivalent.isEmpty && delegate.unlockButton.keyEquivalent.isEmpty, "cleaning keystrokes cannot invoke actions")
        expect(delegate.mode.accessibilityLabel() == "Input to pause" && delegate.duration.accessibilityLabel() == "Pause duration", "settings have accessible names")
        func checkLayout(_ name: String) {
            content.layoutSubtreeIfNeeded()
            for view in descendants(content) where !view.isHidden && (view is NSControl || view is NSBox) {
                let rect = view.convert(view.bounds, to: content)
                expect(content.bounds.insetBy(dx: -1, dy: -1).contains(rect), "\(name): control stays inside window: \(view)")
                if let text = view as? NSTextField, let cell = text.cell {
                    let needed = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: text.bounds.width, height: 1000))
                    expect(needed.height <= text.bounds.height + 1, "\(name): text fits: \(text.stringValue)")
                }
            }
        }
        checkLayout("idle")
        expect(delegate.duration.indexOfSelectedItem == 0, "default is 15 seconds")
        expect(delegate.duration.itemTitles == ["15 seconds", "30 seconds", "60 seconds"], "bounded choices")
        expect(delegate.unlockButton.title == "Unlock Now", "visible mouse unlock")
        expect(delegate.unlockButton.action == #selector(AppDelegate.unlock), "unlock is connected")
        expect(delegate.startButton.action == #selector(AppDelegate.startPause), "start is user action")
        expect(!delegate.gate.state.isActive && !delegate.gate.hasTap, "UI launch never installs tap")
        expect(delegate.mode.itemTitles == ["Keyboard only", "Keyboard + mouse/trackpad"], "explicit mode choices")
        expect(delegate.mode.indexOfSelectedItem == 0, "keyboard-only default")
        expect(delegate.warning.stringValue.contains("Unlock Now is not clickable"), "full-input warning visible")
        expect(delegate.warning.stringValue == "Hold Left Shift + Right Shift for 2 seconds to unlock. Unlock Now is not clickable in full-input mode; rely on the countdown remotely.", "concise recovery guidance without test history")
        delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: .keyboardAndPointer)
        delegate.refresh()
        expect(!delegate.unlockButton.isEnabled, "full-input Unlock Now is not clickable")
        delegate.unlock()
        expect(delegate.unlockButton.isEnabled, "unlock restores button")
        for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
        for action in ["unlock", "sleep", "screenSleep", "session", "quit", "close", "timer"] {
            delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: selectedMode)
            delegate.refresh()
            switch action {
            case "unlock": delegate.unlock()
            case "sleep": delegate.willSleep(Notification(name: NSWorkspace.willSleepNotification))
            case "screenSleep": delegate.willSleep(Notification(name: NSWorkspace.screensDidSleepNotification))
            case "session": delegate.willSleep(Notification(name: NSWorkspace.sessionDidResignActiveNotification))
            case "quit": delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            case "close": delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
            default:
                delegate.gate.state.start(now: InputGate.now() - 16, duration: 15, mode: selectedMode)
                delegate.refresh()
            }
            expect(!delegate.gate.state.isActive && !delegate.gate.hasTap, "\(action) fails open")
        }
            expect(delegate.startButton.isEnabled && delegate.mode.isEnabled && delegate.unlockButton.isEnabled, "lifecycle restores controls")
        }
        delegate.gate.state.start(now: InputGate.now() - 16, duration: 15)
        expect(!delegate.gate.filter(.keyDown), "real callback adapter expires without UI tick")
        delegate.gate.state.start(now: InputGate.now(), duration: 15)
        expect(!delegate.gate.filter(.tapDisabledByTimeout), "disabled adapter passes")
        expect(!delegate.gate.state.isActive, "disabled adapter cancels")
        // Delivered side flags drive recovery without source-table polling.
        // These synthetic events are not a physical reproduction.
        for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            delegate.gate.stop()
            delegate.gate.state.start(now: 100, duration: 15, mode: selectedMode)
            expect(delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20002), at: 101), "left press suppressed")
            expect(delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 102), "both press suppressed")
            _ = delegate.gate.filter(.null, at: 103.99)
            expect(delegate.gate.state.isActive, "no early emergency unlock")
            _ = delegate.gate.filter(.null, at: 104)
            expect(!delegate.gate.state.isActive, "timer unlocks delivered side flags without source-table polling")
            for single in [UInt64(0x20000), 0x20002, 0x20004, 0x6] {
                delegate.gate.stop()
                delegate.gate.state.start(now: 100, duration: 15, mode: selectedMode)
                _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: single), at: 101)
                _ = delegate.gate.filter(.null, at: 104)
                expect(delegate.gate.state.isActive, "single/shared/inconsistent Shift flags cannot unlock")
            }
            delegate.gate.stop()
            delegate.gate.state.start(now: 100, duration: 15, mode: selectedMode)
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 101)
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 102)
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20004), at: 102.9)
            _ = delegate.gate.filter(.null, at: 103)
            expect(delegate.gate.state.isActive, "consumed release resets timer hold")
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 104)
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 105)
            _ = delegate.gate.filter(.null, at: 105.99)
            expect(delegate.gate.state.isActive, "new hold cannot reuse prior timestamp")
            expect(!delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 106), "duplicate event does not toggle; callback unlocks at two seconds")
            delegate.gate.stop()
            delegate.gate.state.start(now: 110, duration: 15, mode: selectedMode)
            _ = delegate.gate.filter(.null, at: 113)
            expect(delegate.gate.state.isActive, "stop clears cached event sides for next pause")
            _ = delegate.gate.filter(.null, at: 125)
            expect(!delegate.gate.state.isActive, "countdown still unlocks without any Shift event")
        }
        print("PASS delivered Shift flags, release, duplicates, restart and countdown")
        for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            delegate.gate.stop()
            delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: selectedMode)
            _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: InputGate.now() - 2.1)
            delegate.refresh()
            expect(!delegate.gate.state.isActive, "UI timer unlocks held shifts without more events")
            delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: selectedMode)
            delegate.gate.state.checkEmergency(leftShift: true, rightShift: true, now: InputGate.now() - 2.1)
            expect(!delegate.gate.filter(.flagsChanged), "callback observes emergency hold")
            expect(!delegate.gate.state.isActive, "callback emergency clears state")
        }
        expect(delegate.warning.stringValue.contains("rely on the countdown"), "candidate warns not to rely on emergency")
        delegate.gate.stop()

        expect(!delegate.gate.hasTap, "smoke never installed an event tap")
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
        }
        let permissionButtons = buttons(in: content).filter { $0.title.contains("Accessibility") }
        expect(permissionButtons.count == 1 && permissionButtons.first?.title == "Accessibility" && permissionButtons.first?.action == #selector(AppDelegate.enableAccessibility), "single Accessibility button is connected")
        var resetCalls = 0
        var permissionRequests = 0
        delegate.confirmAccessibilityReset = { false }
        delegate.runAccessibilityReset = { resetCalls += 1; return 0 }
        delegate.requestAccessibility = { permissionRequests += 1 }
        var settingsOpens = 0
        var choicesShown = 0
        delegate.openAccessibilitySettings = { settingsOpens += 1 }
        delegate.chooseAccessibilityAction = { choicesShown += 1; return .alertFirstButtonReturn }
        delegate.isAccessibilityTrusted = { true }
        delegate.enableAccessibility()
        expect(settingsOpens == 1 && choicesShown == 0 && resetCalls == 0 && permissionRequests == 0, "trusted Accessibility opens settings without prompting or resetting")
        delegate.isAccessibilityTrusted = { false }
        delegate.enableAccessibility()
        expect(choicesShown == 1 && permissionRequests == 1 && resetCalls == 0, "fresh approval requests normally without reset")
        permissionRequests = 0
        delegate.chooseAccessibilityAction = { .alertThirdButtonReturn }
        delegate.enableAccessibility()
        expect(resetCalls == 0 && permissionRequests == 0 && settingsOpens == 1, "cancel Accessibility makes no permission changes")
        delegate.chooseAccessibilityAction = { .alertSecondButtonReturn }
        delegate.gate.state.start(now: InputGate.now(), duration: 15)
        delegate.enableAccessibility()
        expect(!delegate.gate.state.isActive && resetCalls == 0 && permissionRequests == 0, "cancel reset unlocks without resetting or prompting")
        delegate.confirmAccessibilityReset = { true }
        delegate.runAccessibilityReset = { resetCalls += 1; return 7 }
        delegate.enableAccessibility()
        expect(resetCalls == 1 && permissionRequests == 0 && labels(in: content).contains { $0.contains("exit status 7") }, "failed reset is visible and does not request permission")
        delegate.runAccessibilityReset = { throw NSError(domain: "test", code: 1) }
        delegate.enableAccessibility()
        expect(permissionRequests == 0 && labels(in: content).contains { $0.contains("could not run") }, "launch failure is visible without escalation")
        delegate.runAccessibilityReset = { resetCalls += 1; return 0 }
        delegate.enableAccessibility()
        expect(resetCalls == 2 && permissionRequests == 1 && !delegate.gate.state.isActive, "successful reset requests permission without starting pause")
        expect(labels(in: content).contains { $0.contains("System Settings") && $0.contains("Start") }, "successful reset shows approval instructions")
        delegate.isAccessibilityTrusted = { false }
        delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
        expect(labels(in: content).contains { $0.contains("Accessibility is not enabled") }, "activation rechecks denied trust")
        delegate.isAccessibilityTrusted = { true }
        delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
        expect(labels(in: content).contains { $0 == "Ready — Accessibility enabled." }, "activation gives concise ready status after approved trust")
        expect(!delegate.gate.state.isActive && !delegate.gate.hasTap, "permission recovery never starts a pause")
        print("PASS reset cancel, nonzero exit, launch failure, success and activation trust (injected; NO TCC reset)")
        // Only synthetic state: never call startPause, install taps, or ask TCC.
        let previewDirectory = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--preview-directory"
            ? URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true) : nil
        if let previewDirectory { try! FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true) }
        func render(_ name: String) {
            guard let previewDirectory else { return }
            let view = content.window!.contentView!.superview!
            view.layoutSubtreeIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            content.window!.appearance!.performAsCurrentDrawingAppearance {
                view.cacheDisplay(in: view.bounds, to: bitmap)
            }
            let data = bitmap.representation(using: .png, properties: [:])!
            try! data.write(to: previewDirectory.appendingPathComponent(name + ".png"))
            print("RENDER \(name).png (AppKit window only)")
        }
        for (appearance, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark"),
                                   (.accessibilityHighContrastAqua, "high-contrast-light"),
                                   (.accessibilityHighContrastDarkAqua, "high-contrast-dark")] {
            content.window!.appearance = NSAppearance(named: appearance)
            if previewDirectory != nil {
                app.setActivationPolicy(.accessory)
                content.window!.makeKeyAndOrderFront(nil)
                app.activate(ignoringOtherApps: true)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            delegate.unlock()
            delegate.mode.selectItem(at: 0)
            delegate.duration.selectItem(at: 0)
            expect(delegate.duration.titleOfSelectedItem == "15 seconds", "each idle preview restores the launch duration")
            delegate.isAccessibilityTrusted = { true }
            delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
            checkLayout("\(name) idle")
            if name == "light" || name == "dark" { render("design-preview-\(name)") }
            for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
                delegate.mode.selectItem(at: selectedMode == .keyboardOnly ? 0 : 1)
                for (index, seconds) in [15.0, 30, 60].enumerated() {
                    delegate.duration.selectItem(at: index)
                    delegate.gate.state.start(now: InputGate.now(), duration: seconds, mode: selectedMode)
                    delegate.refresh()
                    checkLayout("\(name) active \(selectedMode) \(seconds)")
                    expect(labels(in: content).contains { $0.contains("seconds left") }, "active state has visible countdown")
                    expect(!delegate.mode.isEnabled && !delegate.duration.isEnabled && !delegate.startButton.isEnabled, "active controls reflect pause")
                    if index == 0 && (name == "light" || name == "dark") {
                        render("design-active-\(selectedMode == .keyboardOnly ? "keyboard" : "full")-\(name)")
                    }
                    delegate.unlock()
                    expect(!delegate.gate.hasTap, "layout scenarios never install a tap")
                }
            }
            delegate.isAccessibilityTrusted = { false }
            delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
            checkLayout("\(name) access not enabled")
        }
        print("PASS compact grouped layout, accessible labels, light/dark/high-contrast idle and simulated active layouts (both modes; 15/30/60 seconds)")
        _ = app
        print("PASS AppKit idle UI, callback adapter, unlock/sleep/quit/close/timer lifecycle smoke (NO event tap or permission requests)")
    }
    static func expect(_ condition: Bool, _ message: String) {
        if !condition { print("FAIL: \(message)"); exit(1) }
    }
}
