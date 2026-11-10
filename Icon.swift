import AppKit

// Original vector artwork: a white sculpted keyboard key with a red pause mark.
// Render each standard/Retina representation directly; no downloaded artwork.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
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
        NSGradient(starting: NSColor(white: 0.73, alpha: 1), ending: NSColor(white: 0.97, alpha: 1))!.draw(in: base, angle: 90)
        NSColor(white: 0.60, alpha: 0.65).setStroke()
        base.lineWidth = 3
        base.stroke()
        let face = NSBezierPath(roundedRect: NSRect(x: 184, y: 292, width: 656, height: 600), xRadius: 100, yRadius: 100)
        NSGradient(starting: NSColor(white: 0.92, alpha: 1), ending: .white)!.draw(in: face, angle: 90)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        face.lineWidth = 4
        face.stroke()
        NSColor(srgbRed: 0.82, green: 0.10, blue: 0.13, alpha: 1).setFill()
        for x in [CGFloat(370), 558] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 452, width: 96, height: 276), xRadius: 12, yRadius: 12).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
print("Rendered ten original keyboard-key icon representations (16–1024 pixels)")
