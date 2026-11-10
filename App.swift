import AppKit
import ApplicationServices
import Darwin

// All access is on the main run loop, including the event-tap callback.
final class InputGate {
    var state = PauseState()
    private var eventShifts = (false, false)
    static func shiftSides(_ flags: CGEventFlags) -> (Bool, Bool) {
        // Public IOKit/hidsystem/IOLLEvent.h: NX_DEVICELSHIFTKEYMASK (2),
        // NX_DEVICERSHIFTKEYMASK (4). The shared Shift bit alone is insufficient.
        guard flags.contains(.maskShift) else { return (false, false) }
        return (flags.rawValue & 0x2 != 0, flags.rawValue & 0x4 != 0)
    }

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
            return "Accessibility is not enabled (AXIsProcessTrusted returned false). Click Accessibility, approve InputPause in System Settings, then click Start again."
        }
        let mask = mode.eventMask
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let gate = Unmanaged<InputGate>.fromOpaque(context).takeUnretainedValue()
            // Inspect only modifier flags or the auxiliary-control identifier;
            // no text or input history is retained.
            return gate.filter(type, event: event, flags: type == .flagsChanged ? event.flags : nil) ? nil : Unmanaged.passUnretained(event)
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

    func filter(_ type: CGEventType, event: CGEvent? = nil, flags: CGEventFlags? = nil, at now: TimeInterval = InputGate.now()) -> Bool {
        // Deadline checked for EACH event, independently of countdown/UI timer.
        if state.isActive {
            if type == .flagsChanged, let flags { eventShifts = Self.shiftSides(flags) }

            // Timer reuses delivered state; polling must not erase a consumed press.
            state.checkEmergency(leftShift: eventShifts.0, rightShift: eventShifts.1, now: now)
        }
        let suppress = state.shouldSuppress(type: type, now: now)
        if !state.isActive, let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        guard state.isActive, type.rawValue == 14 else { return suppress }
        // NX_SYSDEFINED / NX_SUBTYPE_AUX_CONTROL_BUTTONS, from public
        // IOKit hidsystem headers. Other subtypes include power/sleep/restart,
        // accessibility and auxiliary mouse events: always pass those through.
        guard let event, event.type == type, let auxiliary = NSEvent(cgEvent: event),
              auxiliary.type == .systemDefined, auxiliary.subtype.rawValue == 8 else { return false }
        let key = (auxiliary.data1 >> 16) & 0xFFFF
        let transition = (auxiliary.data1 >> 8) & 0xFF
        guard transition == 0xA || transition == 0xB else { return false }
        // ev_keymap.h: volume, brightness, mute, contrast, launch panel,
        // video mirror, playback/seek and keyboard illumination. Down, repeat
        // and up follow the same rule. Never blanket-consume auxiliary keys:
        // NX_POWER_KEY (6), eject (14) and unknown identifiers pass through.
        return [0, 1, 2, 3, 7, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21, 22, 23].contains(key)
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
    let warning = NSTextField(wrappingLabelWithString: "Hold Left Shift + Right Shift for 2 seconds to unlock. Unlock Now is not clickable in full-input mode; rely on the countdown remotely.")

    let startButton = NSButton(title: "Start Timed Pause", target: nil, action: nil)
    let unlockButton = NSButton(title: "Unlock Now", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "Ready — input is not paused.")
    private var window: NSWindow!
    private var timer: Timer?
    var confirmAccessibilityReset: () -> Bool = {
        let prompt = NSAlert()
        prompt.messageText = "Reset InputPause Accessibility?"
        prompt.informativeText = "This clears Accessibility approval for all copies with bundle ID local.inputpause.app, not just this copy. Other apps are unaffected. You will need to approve InputPause again in System Settings. Input will remain unlocked."
        prompt.addButton(withTitle: "Cancel")
        prompt.addButton(withTitle: "Reset Accessibility")
        return prompt.runModal() == .alertSecondButtonReturn
    }
    var runAccessibilityReset: () throws -> Int32 = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "local.inputpause.app"]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
    var requestAccessibility: () -> Void = {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
    var isAccessibilityTrusted: () -> Bool = { AXIsProcessTrusted() }

    @objc func resetAccessibility() {
        unlock()
        guard confirmAccessibilityReset() else { return }
        do {
            let result = try runAccessibilityReset()
            guard result == 0 else {
                status.stringValue = "Accessibility reset failed (exit status \(result)). Input remains unlocked. No further changes were attempted."
                return
            }
            status.stringValue = "Accessibility reset. Approve InputPause in System Settings → Privacy & Security → Accessibility, then click Start when ready. Input remains unlocked."
            requestAccessibility()
        } catch {
            status.stringValue = "Accessibility reset could not run: \(error.localizedDescription). Input remains unlocked."
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !gate.state.isActive else { return }
        status.stringValue = isAccessibilityTrusted()
            ? "Ready — Accessibility enabled."
            : "Accessibility is not enabled. Approve InputPause in System Settings → Privacy & Security → Accessibility, then click Start when ready."
    }

    func buildUI() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "InputPause"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let heading = NSTextField(labelWithString: "Pause input for cleaning")
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        let instructions = NSTextField(wrappingLabelWithString: "Release all keys and buttons before starting.")
        instructions.textColor = .secondaryLabelColor
        mode.addItems(withTitles: ["Keyboard only", "Keyboard + mouse/trackpad"])
        mode.selectItem(at: 0)
        mode.setAccessibilityLabel("Input to pause")
        mode.toolTip = "Keyboard only keeps your mouse usable. The other mode also pauses pointer movement, buttons, dragging, and scrolling."
        duration.addItems(withTitles: ["15 seconds", "30 seconds", "60 seconds"])
        duration.selectItem(at: 0)
        duration.setAccessibilityLabel("Pause duration")
        let settings = NSBox()
        settings.titlePosition = .noTitle
        settings.contentViewMargins = NSSize(width: 14, height: 12)
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Pause"), mode],
            [NSTextField(labelWithString: "Duration"), duration]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        settings.contentView!.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: settings.contentView!.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: settings.contentView!.trailingAnchor),
            grid.topAnchor.constraint(equalTo: settings.contentView!.topAnchor),
            grid.bottomAnchor.constraint(equalTo: settings.contentView!.bottomAnchor)
        ])
        startButton.target = self; startButton.action = #selector(startPause)
        unlockButton.target = self; unlockButton.action = #selector(unlock)
        for button in [startButton, unlockButton] {
            button.bezelStyle = .rounded
            button.controlSize = .large
        }
        startButton.bezelColor = .controlAccentColor
        startButton.font = .systemFont(ofSize: 13, weight: .semibold)
        startButton.setAccessibilityHelp("Pauses the selected input until the countdown ends. Release all keys and buttons first.")
        unlockButton.setAccessibilityHelp("Ends the pause early. Unavailable while mouse and trackpad input is paused.")
        // No keyboard equivalents: accidental cleaning keystrokes cannot start a pause.
        let actions = NSStackView(views: [startButton, unlockButton])
        actions.orientation = .horizontal
        actions.spacing = 12
        actions.distribution = .fillEqually
        let permission = NSButton(title: "Accessibility", target: self, action: #selector(enableAccessibility))
        permission.bezelStyle = .rounded
        permission.setAccessibilityHelp("Manage InputPause Accessibility access.")

        warning.font = .systemFont(ofSize: 12)
        warning.textColor = .secondaryLabelColor
        status.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        status.setAccessibilityLabel("Pause status")
        let stack = NSStackView(views: [heading, instructions, settings, status, actions, warning, permission])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(6, after: heading)
        stack.setCustomSpacing(20, after: instructions)
        stack.setCustomSpacing(16, after: actions)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        for view in [instructions, settings, status, actions, warning] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            startButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            unlockButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
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

    var openAccessibilitySettings: () -> Void = {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    var chooseAccessibilityAction: () -> NSApplication.ModalResponse = {
        let prompt = NSAlert()
        prompt.messageText = "Accessibility"
        prompt.informativeText = "Allow InputPause to pause input without recording typed text. If approval is already enabled but not working, reset it and approve again. Input stays unlocked."
        prompt.addButton(withTitle: "Request Access")
        prompt.addButton(withTitle: "Reset & Request Access…")
        prompt.addButton(withTitle: "Cancel")
        return prompt.runModal()
    }

    @objc func enableAccessibility() {
        unlock()
        if isAccessibilityTrusted() {
            openAccessibilitySettings()
            return
        }
        switch chooseAccessibilityAction() {
        case .alertFirstButtonReturn: requestAccessibility()
        case .alertSecondButtonReturn: resetAccessibility()
        default: break
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
