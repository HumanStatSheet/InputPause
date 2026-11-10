import AppKit
import ApplicationServices
import Darwin

// All access is on the main run loop, including the event-tap callback.
final class InputGate {
    var state = PauseState()
    // Source-table polling is diagnostic only: it need not match delivered events.
    private var eventShifts = (false, false)
    static func shiftSides(_ flags: CGEventFlags) -> (Bool, Bool) {
        // Public IOKit/hidsystem/IOLLEvent.h: NX_DEVICELSHIFTKEYMASK (2),
        // NX_DEVICERSHIFTKEYMASK (4). The shared Shift bit alone is insufficient.
        guard flags.contains(.maskShift) else { return (false, false) }
        return (flags.rawValue & 0x2 != 0, flags.rawValue & 0x4 != 0)
    }
    var shiftKeysDown: () -> (Bool, Bool) = {
        (CGEventSource.keyState(.hidSystemState, key: 56),
         CGEventSource.keyState(.hidSystemState, key: 60))
    }
    var shiftSourceFlags: (CGEventSourceStateID) -> CGEventFlags = { CGEventSource.flagsState($0) }
    private(set) var shiftDiagnostic = "Shift diagnostic: no active-pause sample."
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var hasTap: Bool { tap != nil }
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    static func now() -> TimeInterval {
        Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    // Invoked only by the Start button; never on startup or from command-line flags.
    func start(duration: TimeInterval, mode: PauseMode = .keyboardOnly) -> String? {
        stop()
        guard AXIsProcessTrusted() else {
            return "Accessibility is not enabled (AXIsProcessTrusted returned false). Click Enable Accessibility, approve InputPause in System Settings, then click Start again."
        }
        let mask = mode.eventMask
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let gate = Unmanaged<InputGate>.fromOpaque(context).takeUnretainedValue()
            // Read only modifier flags, before potentially consuming the event.
            return gate.filter(type, flags: type == .flagsChanged ? event.flags : nil) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return "CGEvent.tapCreate returned nil. Input is NOT paused. Check InputPause in Privacy & Security → Accessibility and (if macOS lists or requests it) Input Monitoring; quit and reopen after approval."
        }
        guard let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return "CFMachPortCreateRunLoopSource failed. Input is NOT paused."
        }
        tap = port
        source = runSource
        state.start(now: Self.now(), duration: duration, mode: mode)
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        guard state.isActive && CGEvent.tapIsEnabled(tap: port) else {
            stop()
            return "CGEvent.tapIsEnabled returned false, or duration was invalid. Input is NOT paused."
        }
        return nil
    }

    func filter(_ type: CGEventType, flags: CGEventFlags? = nil, at now: TimeInterval = InputGate.now()) -> Bool {
        // Deadline checked for EACH event, independently of countdown/UI timer.
        if state.isActive {
            if type == .flagsChanged, let flags { eventShifts = Self.shiftSides(flags) }
            if type == .null {
                // Boolean-only, latest sample in memory/UI; never a log or file.
                let keys = shiftKeysDown()
                let hid = Self.shiftSides(shiftSourceFlags(.hidSystemState))
                let session = Self.shiftSides(shiftSourceFlags(.combinedSessionState))
                shiftDiagnostic = "Shift L/R — event: \(eventShifts.0)/\(eventShifts.1); HID keys: \(keys.0)/\(keys.1); HID flags: \(hid.0)/\(hid.1); session flags: \(session.0)/\(session.1)"
            }
            // Timer reuses delivered state; polling must not erase a consumed press.
            state.checkEmergency(leftShift: eventShifts.0, rightShift: eventShifts.1, now: now)
        }
        let suppress = state.shouldSuppress(type: type, now: now)
        if !state.isActive, let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        return suppress
    }

    func stop() {
        state = PauseState() // Fail open before touching resources.
        eventShifts = (false, false)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let gate = InputGate()
    let duration = NSPopUpButton()
    let mode = NSPopUpButton()
    let warning = NSTextField(wrappingLabelWithString: "1.1.1: hold LEFT SHIFT + RIGHT SHIFT together for 2 seconds to unlock. Physical keyboard-only recovery is user-confirmed. Unlock Now is not clickable in full-input mode; rely on the countdown remotely. Use 15 seconds for initial attended testing.")
    let diagnostic = NSTextField(wrappingLabelWithString: "Shift diagnostic: no active-pause sample.")
    let startButton = NSButton(title: "Start Timed Pause", target: nil, action: nil)
    let unlockButton = NSButton(title: "Unlock Now", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "Ready — input is not paused.")
    private var window: NSWindow!
    private var timer: Timer?

    func buildUI() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "InputPause"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let heading = NSTextField(labelWithString: "Pause input for cleaning")
        heading.font = .boldSystemFont(ofSize: 24)
        let instructions = NSTextField(wrappingLabelWithString: "Keyboard only keeps your mouse usable. Optionally pause mouse/trackpad buttons, motion, dragging and scrolling too. Release all keys and buttons before starting.")
        mode.addItems(withTitles: ["Keyboard only", "Keyboard + mouse/trackpad"])
        mode.selectItem(at: 0)
        mode.setAccessibilityLabel("Input to pause")
        warning.font = .boldSystemFont(ofSize: 13)
        duration.addItems(withTitles: ["15 seconds", "30 seconds", "60 seconds"])
        duration.selectItem(at: 0)
        duration.setAccessibilityLabel("Pause duration")
        startButton.target = self; startButton.action = #selector(startPause)
        unlockButton.target = self; unlockButton.action = #selector(unlock)
        unlockButton.font = .boldSystemFont(ofSize: 20)
        // No keyboard equivalents: accidental cleaning keystrokes cannot start a pause.
        let permission = NSButton(title: "Enable Accessibility…", target: self, action: #selector(enableAccessibility))
        let privacy = NSTextField(wrappingLabelWithString: "No key recording, networking, or saved settings. Media/Fn/power keys and protected system shortcuts may still work. Not a security lock.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        status.font = .boldSystemFont(ofSize: 15)
        diagnostic.font = .systemFont(ofSize: 11)
        let stack = NSStackView(views: [heading, instructions, mode, duration, warning, status, diagnostic, startButton, unlockButton, permission, privacy])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24),
            unlockButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit InputPause", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item)
        NSApplication.shared.mainMenu = menu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc func enableAccessibility() {
        unlock()
        let prompt = NSAlert()
        prompt.messageText = "Allow InputPause to pause input events?"
        prompt.informativeText = "macOS requires Accessibility for the suppressing event tap. InputPause inspects event types and Shift modifier state; it never reads or records typed text. Enable InputPause in System Settings. This does not start a pause."
        prompt.addButton(withTitle: "Request Accessibility")
        prompt.addButton(withTitle: "Cancel")
        if prompt.runModal() == .alertFirstButtonReturn {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
    }

    @objc func startPause() {
        guard !gate.state.isActive else { return }
        let seconds = [15.0, 30, 60][max(0, duration.indexOfSelectedItem)]
        if let error = gate.start(duration: seconds, mode: mode.indexOfSelectedItem == 1 ? .keyboardAndPointer : .keyboardOnly) {
            status.stringValue = error
            return
        }
        window.level = .floating
        refresh()
    }

    @objc func unlock() {
        gate.stop()
        startButton.isEnabled = true
        unlockButton.isEnabled = true
        duration.isEnabled = true
        mode.isEnabled = true
        window?.level = .normal
        status.stringValue = "Unlocked — input is not paused."
    }
    @objc func willSleep(_ notification: Notification) { unlock() }
    func windowWillClose(_ notification: Notification) { unlock() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        unlock()
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func refresh() {
        _ = gate.filter(.null)
        diagnostic.stringValue = gate.shiftDiagnostic
        if !gate.state.isActive {
            if gate.hasTap || !startButton.isEnabled { unlock() }
            return
        }
        startButton.isEnabled = false
        duration.isEnabled = false
        mode.isEnabled = false
        unlockButton.isEnabled = gate.state.mode == .keyboardOnly
        let inputs = gate.state.mode == .keyboardOnly ? "Keyboard" : "Keyboard + mouse/trackpad"
        status.stringValue = "\(inputs) paused — \(Int(ceil(gate.state.remaining(now: InputGate.now())))) seconds left"
    }
}
