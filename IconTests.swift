import AppKit

// Non-actuating resource contract: inspect the real generated bundle and iconset.
@main struct IconTests {
    static func main() throws {
        func expect(_ condition: Bool, _ message: String) {
            if !condition { print("FAIL: \(message)"); exit(1) }
        }
        let contents = URL(fileURLWithPath: "build/InputPause.app/Contents")
        let plist = NSDictionary(contentsOf: contents.appendingPathComponent("Info.plist"))!
        expect(plist["CFBundleIconFile"] as? String == "InputPause.icns", "bundle declares the application icon")
        let iconURL = contents.appendingPathComponent("Resources/InputPause.icns")
        expect(NSImage(contentsOf: iconURL) != nil, "bundle contains a readable ICNS")
        let darkURL = contents.appendingPathComponent("Resources/InputPause-dark.icns")
        expect(NSImage(contentsOf: darkURL) != nil, "bundle contains the dark icon artwork without claiming automatic switching")
        for variant in ["InputPause", "InputPause-dark"] {
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let suffix = scale == 2 ? "@2x" : ""
                let url = URL(fileURLWithPath: "build/\(variant).iconset/icon_\(size)x\(size)\(suffix).png")
                let image = NSBitmapImageRep(data: try Data(contentsOf: url))!
                let pixels = size * scale
                expect(image.pixelsWide == pixels && image.pixelsHigh == pixels, "correct standard/Retina dimensions")
                let symbol = image.colorAt(x: pixels * 42 / 100, y: pixels * 43 / 100)!.usingColorSpace(.deviceRGB)!
                expect(symbol.redComponent > 0.6 && symbol.greenComponent < 0.35 && symbol.blueComponent < 0.35, "pause symbol is red")
                // Stay clear of the antialiased red bar at 16 px.
                let key = image.colorAt(x: pixels / 2, y: pixels / 5)!.usingColorSpace(.deviceRGB)!
                if variant == "InputPause" {
                    expect(key.redComponent > 0.85 && key.greenComponent > 0.85 && key.blueComponent > 0.85, "key face is white")
                } else {
                    expect(key.redComponent < 0.35 && key.greenComponent < 0.35 && key.blueComponent < 0.35 && key.redComponent > 0.08, "dark key face is charcoal")
                }
                expect(image.colorAt(x: 0, y: 0)!.alphaComponent == 0, "icon corners are transparent")
            }
        }
        }
        print("PASS bundle ICNS declaration, twenty standard/Retina images, white/charcoal keys, red pause and transparency")
    }
}
