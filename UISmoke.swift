import AppKit
import CoreGraphics

@main struct UISmoke {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        delegate.buildUI()
        let content = app.windows.first!.contentView!
        content.layoutSubtreeIfNeeded()
        expect(content.fittingSize.height <= content.bounds.height, "all controls fit without clipping")
        expect(delegate.duration.indexOfSelectedItem == 0, "default is 15 seconds")
        expect(delegate.duration.itemTitles == ["15 seconds", "30 seconds", "60 seconds"], "bounded choices")
        expect(delegate.unlockButton.title == "Unlock Now", "visible mouse unlock")
        expect(delegate.unlockButton.action == #selector(AppDelegate.unlock), "unlock is connected")
        expect(delegate.startButton.action == #selector(AppDelegate.startPause), "start is user action")
        expect(!delegate.gate.state.isActive && !delegate.gate.hasTap, "UI launch never installs tap")
        expect(delegate.mode.itemTitles == ["Keyboard only", "Keyboard + mouse/trackpad"], "explicit mode choices")
        expect(delegate.mode.indexOfSelectedItem == 0, "keyboard-only default")
        expect(delegate.warning.stringValue.contains("Unlock Now is not clickable"), "full-input warning visible")
        expect(delegate.warning.stringValue.contains("LEFT SHIFT + RIGHT SHIFT"), "emergency shortcut visible")
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
        // Model a source-table mismatch: delivered side flags are present, but
        // polling reports neither key down. This is not a physical reproduction.
        delegate.gate.shiftKeysDown = { (false, false) }
        for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            delegate.gate.stop()
            delegate.gate.state.start(now: 100, duration: 15, mode: selectedMode)
            expect(delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20002), at: 101), "left press suppressed")
            expect(delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 102), "both press suppressed")
            _ = delegate.gate.filter(.null, at: 103.99)
            expect(delegate.gate.state.isActive, "no early emergency unlock")
            _ = delegate.gate.filter(.null, at: 104)
            expect(!delegate.gate.state.isActive, "timer unlocks delivered side flags despite false HID key table")
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
        print("PASS delivered Shift flags, source mismatch model, release, duplicates, restart and countdown")
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
        delegate.gate.shiftKeysDown = { (true, false) }
        delegate.gate.shiftSourceFlags = { source in
            source == .hidSystemState ? CGEventFlags(rawValue: 0x20002) : CGEventFlags(rawValue: 0x20006)
        }
        delegate.gate.state.start(now: 100, duration: 15)
        _ = delegate.gate.filter(.flagsChanged, flags: CGEventFlags(rawValue: 0x20006), at: 101)
        _ = delegate.gate.filter(.null, at: 101)
        expect(delegate.gate.shiftDiagnostic == "Shift L/R — event: true/true; HID keys: true/false; HID flags: true/false; session flags: true/true", "boolean diagnostic distinguishes event and source tables")
        let snapshot = delegate.gate.shiftDiagnostic
        delegate.gate.stop()
        _ = delegate.gate.filter(.null, at: 102)
        expect(delegate.gate.shiftDiagnostic == snapshot, "diagnostic retained after unlock without idle polling")
        expect(!delegate.gate.hasTap, "smoke never installed an event tap")
        _ = app
        print("PASS AppKit idle UI, callback adapter, unlock/sleep/quit/close/timer lifecycle smoke (NO event tap or permission requests)")
    }
    static func expect(_ condition: Bool, _ message: String) {
        if !condition { print("FAIL: \(message)"); exit(1) }
    }
}
