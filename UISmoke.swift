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
        delegate.gate.shiftKeysDown = { (true, true) }
        for selectedMode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: selectedMode)
            delegate.gate.state.checkEmergency(leftShift: true, rightShift: true, now: InputGate.now() - 2.1)
            delegate.refresh()
            expect(!delegate.gate.state.isActive, "UI timer unlocks held shifts without more events")
            delegate.gate.state.start(now: InputGate.now(), duration: 15, mode: selectedMode)
            delegate.gate.state.checkEmergency(leftShift: true, rightShift: true, now: InputGate.now() - 2.1)
            expect(!delegate.gate.filter(.flagsChanged), "callback observes emergency hold")
            expect(!delegate.gate.state.isActive, "callback emergency clears state")
        }
        expect(!delegate.gate.hasTap, "smoke never installed an event tap")
        _ = app
        print("PASS AppKit idle UI, callback adapter, unlock/sleep/quit/close/timer lifecycle smoke (NO event tap or permission requests)")
    }
    static func expect(_ condition: Bool, _ message: String) {
        if !condition { print("FAIL: \(message)"); exit(1) }
    }
}
