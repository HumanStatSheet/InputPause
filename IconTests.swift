import AppKit

// Non-actuating resource contract: inspect the real generated bundle and iconset.
@main struct IconTests {
    static func main() throws {
        func expect(_ condition: Bool, _ message: String) {
            if !condition { print("FAIL: \(message)"); exit(1) }
        }
        let contents = URL(fileURLWithPath: "build/InputPause.app/Contents")
        let plist = NSDictionary(contentsOf: contents.appendingPathComponent("Info.plist"))!
        expect(FileManager.default.fileExists(atPath: contents.appendingPathComponent("Resources/Assets.car").path), "compiled native appearance catalog exists")
        expect(plist["CFBundleIconName"] as? String == "InputPause", "bundle selects native appearance-aware icon")
        expect(plist["CFBundleIconFile"] as? String == "InputPause", "bundle declares Apple's generated legacy fallback")
        let iconURL = contents.appendingPathComponent("Resources/InputPause.icns")
        expect(NSImage(contentsOf: iconURL) != nil, "bundle contains a readable ICNS")
        let records = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "build/icon-assets.json"))) as! [[String: Any]]
        for (appearance, artwork) in [("NSAppearanceNameAqua", "key-light"), ("NSAppearanceNameDarkAqua", "key-dark")] {
            expect(records.contains { record in
                guard record["AssetType"] as? String == "IconGroup",
                      record["Appearance"] as? String == appearance,
                      let layers = record["Layers"] as? [[String: Any]] else { return false }
                return layers.contains { ($0["Name"] as? String)?.hasSuffix(artwork) == true }
            }, "compiled catalog maps \(appearance) to \(artwork)")
        }
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
        print("PASS compiled Aqua/DarkAqua artwork mapping, legacy ICNS, twenty standard/Retina images, white/charcoal keys, red pause and transparency")
    }
}
