import Foundation
import CoreGraphics

enum PauseMode {
    case keyboardOnly, keyboardAndPointer

    var eventTypes: [CGEventType] {
        let keyboard: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        guard self == .keyboardAndPointer else { return keyboard }
        return keyboard + [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged, .scrollWheel]
    }
    var eventMask: CGEventMask {
        // NX_SYSDEFINED (14) is absent from CGEventType's named cases.
        // Subscribe in both modes, but classify its payload separately: power,
        // sleep and unrelated system notifications must not be blanket-blocked.
        eventTypes.reduce(CGEventMask(1) << 14) { $0 | (CGEventMask(1) << $1.rawValue) }
    }
}

// Pure policy shared by the real event callback and deterministic tests.
struct PauseState {
    private var deadline: TimeInterval?
    private var shiftHoldStart: TimeInterval?
    var isActive: Bool { deadline != nil }
    private(set) var mode: PauseMode = .keyboardOnly
    mutating func start(now: TimeInterval, duration: TimeInterval, mode: PauseMode = .keyboardOnly) {
        self.mode = mode
        shiftHoldStart = nil
        guard now.isFinite, [15.0, 30, 60].contains(duration) else {
            deadline = nil
            return
        }
        deadline = now + duration
    }
    mutating func shouldSuppress(type: CGEventType, now: TimeInterval) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput || remaining(now: now) <= 0 {
            deadline = nil
        }
        return isActive && mode.eventTypes.contains(type)
    }
    mutating func checkEmergency(leftShift: Bool, rightShift: Bool, now: TimeInterval) {
        guard isActive, leftShift, rightShift else {
            shiftHoldStart = nil
            return
        }
        if shiftHoldStart == nil { shiftHoldStart = now }
        if now - shiftHoldStart! >= 2 {
            deadline = nil
            shiftHoldStart = nil
        }
    }
    func remaining(now: TimeInterval) -> TimeInterval {
        max(0, (deadline ?? now) - now)
    }
}
