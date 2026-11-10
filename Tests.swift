import Foundation
import CoreGraphics

@main struct Tests {
    static func main() {
        var gate = PauseState()
        expect(!gate.isActive, "launch is idle")
        gate.start(now: 100, duration: 15)
        expect(gate.isActive, "explicit start activates")
        expect(gate.remaining(now: 114) == 1, "monotonic remaining time")
        expect(gate.remaining(now: 115) == 0, "exact deadline expires")
        print("PASS deadline/start tests")
        for type in [CGEventType.keyDown, .keyUp, .flagsChanged] {
            gate.start(now: 100, duration: 15)
            expect(gate.shouldSuppress(type: type, now: 114), "keyboard suppressed before deadline")
            expect(!gate.shouldSuppress(type: type, now: 115), "callback fails open at deadline")
            expect(!gate.isActive, "callback expires state without UI timer")
        }
        gate.start(now: 100, duration: 15)
        for type in [CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .mouseMoved, .scrollWheel, .otherMouseDown] {
            expect(!gate.shouldSuppress(type: type, now: 101), "mouse always passes")
        }
        print("PASS keyboard-only callback filtering tests")
        let pointerTypes: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged, .scrollWheel]
        for type in pointerTypes {
            gate.start(now: 100, duration: 15, mode: .keyboardAndPointer)
            expect(gate.shouldSuppress(type: type, now: 114), "full-input mode suppresses \(type)")
            expect(!gate.shouldSuppress(type: type, now: 115), "pointer passes at exact deadline")
            expect(!gate.isActive, "pointer callback expires without timer")
        }
        print("PASS full-input pointer types and deadline recovery")
        for mode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            let expected = [CGEventType.keyDown, .keyUp, .flagsChanged] + (mode == .keyboardAndPointer ? pointerTypes : [])
            let expectedMask = expected.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
            expect(mode.eventMask == expectedMask, "tap mask exactly matches selected mode")
            for duration in [15.0, 30, 60] {
                for type in expected {
                    gate.start(now: 100, duration: duration, mode: mode)
                    expect(gate.shouldSuppress(type: type, now: 100 + duration - 0.01), "selected event suppressed")
                    expect(!gate.shouldSuppress(type: type, now: 100 + duration), "each duration expires")
                }
            }
            for disabled in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
                gate.start(now: 100, duration: 15, mode: mode)
                expect(!gate.shouldSuppress(type: .null, now: 101), "unsubscribed event passes")
                expect(!gate.shouldSuppress(type: disabled, now: 101), "disabled passes in both modes")
                for type in expected {
                    expect(!gate.shouldSuppress(type: type, now: 102), "disabled tap never resumes")
                }
            }
        }
        print("PASS exact masks, all durations, both-mode disabled recovery")
        for type in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            gate.start(now: 100, duration: 15)
            expect(!gate.shouldSuppress(type: type, now: 101), "disabled notification passes")
            expect(!gate.isActive, "disabled tap cancels, never resumes")
            expect(!gate.shouldSuppress(type: .keyDown, now: 102), "disabled tap remains fail-open")
        }
        print("PASS disabled-tap fail-open tests")
        for duration in [0.0, -1, 16, Double.nan, Double.infinity] {
            gate.start(now: 100, duration: duration)
            expect(!gate.isActive, "invalid duration must fail open")
        }
        print("PASS duration validation tests")
        for mode in [PauseMode.keyboardOnly, .keyboardAndPointer] {
            gate.start(now: 100, duration: 15, mode: mode)
            gate.checkEmergency(leftShift: true, rightShift: false, now: 101)
            gate.checkEmergency(leftShift: true, rightShift: false, now: 104)
            expect(gate.isActive, "single left shift cannot unlock")
            gate.checkEmergency(leftShift: false, rightShift: true, now: 104)
            gate.checkEmergency(leftShift: false, rightShift: true, now: 107)
            expect(gate.isActive, "single right shift cannot unlock")
            gate.checkEmergency(leftShift: true, rightShift: true, now: 107)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 107)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 108.99)
            expect(gate.isActive, "duplicate samples stable; no early unlock")
            gate.checkEmergency(leftShift: false, rightShift: true, now: 108.99)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 109)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 110.99)
            expect(gate.isActive, "release resets hold")
            gate.checkEmergency(leftShift: true, rightShift: true, now: 111)
            expect(!gate.isActive, "both shifts held two seconds unlock")
            gate.start(now: 112, duration: 15, mode: mode)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 112)
            expect(gate.isActive, "new pause resets previous hold")
            _ = gate.shouldSuppress(type: .tapDisabledByTimeout, now: 113)
            gate.checkEmergency(leftShift: true, rightShift: true, now: 114)
            expect(!gate.isActive, "emergency sampling cannot reactivate disabled state")
        }
        print("PASS both-mode opposite Shift hold, release, duplicate and cancellation")
    }
    static func expect(_ condition: Bool, _ message: String) {
        if !condition { print("FAIL: \(message)"); exit(1) }
    }
}
