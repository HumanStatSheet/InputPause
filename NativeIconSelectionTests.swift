import AppKit
import CoreGraphics

// Read-only acceptance probe: the OS chooses the bundle icon. This does not
// choose an artwork file, set any appearance, launch InputPause, or request TCC.
// Run a fresh process after changing Icon & widget style in System Settings.
@main struct NativeIconSelectionTests {
    static func main() throws {
        guard CommandLine.arguments.count == 4,
              ["light", "dark"].contains(CommandLine.arguments[2]) else {
            print("Usage: native-icon-tests /path/to/InputPause.app light|dark output.png")
            exit(2)
        }
        _ = NSApplication.shared
        let path = CommandLine.arguments[1]
        let dark = CommandLine.arguments[2] == "dark"
        let image = NSWorkspace.shared.icon(forFile: path)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
        let face = rep.colorAt(x: 256, y: 140)!.usingColorSpace(.deviceRGB)!
        let bar = rep.colorAt(x: 220, y: 230)!.usingColorSpace(.deviceRGB)!
        print("OS-selected icon: \(path); expected=\(dark ? "dark" : "light"); face=\(face); pause=\(bar)")
        print("Screen capture preflight=\(CGPreflightScreenCaptureAccess()); output is an NSWorkspace icon render, not a screenshot")
        let components = [face.redComponent, face.greenComponent, face.blueComponent]
        guard components.allSatisfy({ dark ? ($0 > 0.08 && $0 < 0.35) : $0 > 0.85 }),
              bar.redComponent > 0.6, bar.greenComponent < 0.35, bar.blueComponent < 0.35 else {
            print("FAIL: OS-selected icon must have the expected white/charcoal face and red pause")
            exit(1)
        }
        print("PASS native OS-selected \(dark ? "charcoal" : "white") keycap with red pause")
    }
}
