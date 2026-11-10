import AppKit

// Original vector artwork: white/charcoal keyboard keys with a red pause mark.
// Render each standard/Retina representation directly; no downloaded artwork.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let dark = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "dark"
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 112, y: 112, width: 800, height: 800), xRadius: 140, yRadius: 140)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        // NSShadow uses device-space lengths, unlike the transformed paths.
        shadow.shadowBlurRadius = CGFloat(pixels) * 24 / 1024
        shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixels) * 18 / 1024)
        shadow.set()
        NSColor(white: 0.76, alpha: 1).setFill()
        base.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(white: dark ? 0.07 : 0.73, alpha: 1), ending: NSColor(white: dark ? 0.18 : 0.97, alpha: 1))!.draw(in: base, angle: 90)
        NSColor(white: dark ? 0.04 : 0.60, alpha: 0.65).setStroke()
        base.lineWidth = 3
        base.stroke()
        let face = NSBezierPath(roundedRect: NSRect(x: 184, y: 292, width: 656, height: 600), xRadius: 100, yRadius: 100)
        NSGradient(starting: NSColor(white: dark ? 0.14 : 0.92, alpha: 1), ending: NSColor(white: dark ? 0.24 : 1, alpha: 1))!.draw(in: face, angle: 90)
        NSColor(white: dark ? 0.34 : 1, alpha: 0.95).setStroke()
        face.lineWidth = 4
        face.stroke()
        NSColor(srgbRed: dark ? 0.95 : 0.82, green: dark ? 0.15 : 0.10, blue: dark ? 0.18 : 0.13, alpha: 1).setFill()
        for x in [CGFloat(370), 558] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 452, width: 96, height: 276), xRadius: 12, yRadius: 12).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
print("Rendered ten \(dark ? "charcoal" : "white") keyboard-key icon representations (16–1024 pixels)")
