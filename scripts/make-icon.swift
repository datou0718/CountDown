import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        // Render at exact pixel sizes, independent of the Mac's display scale.
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            .retagging(with: .sRGB)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let s = CGFloat(pixels)
        let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
        let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.20, yRadius: s * 0.20)
        NSColor(srgbRed: 1 / 255, green: 33 / 255, blue: 105 / 255, alpha: 1).setFill()
        path.fill()
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: s * x, y: s * y) }
        NSColor.white.setStroke()
        NSColor.white.setFill()

        // A crisp white hourglass, with the navy showing through its outline.
        let glass = NSBezierPath()
        glass.move(to: point(0.35, 0.74))
        glass.curve(to: point(0.47, 0.50), controlPoint1: point(0.35, 0.61), controlPoint2: point(0.47, 0.56))
        glass.curve(to: point(0.35, 0.26), controlPoint1: point(0.47, 0.44), controlPoint2: point(0.35, 0.39))
        glass.line(to: point(0.65, 0.26))
        glass.curve(to: point(0.53, 0.50), controlPoint1: point(0.65, 0.39), controlPoint2: point(0.53, 0.44))
        glass.curve(to: point(0.65, 0.74), controlPoint1: point(0.53, 0.56), controlPoint2: point(0.65, 0.61))
        glass.close()
        glass.lineWidth = s * 0.025
        glass.lineJoinStyle = .round
        glass.stroke()

        let caps = NSBezierPath()
        for y: CGFloat in [0.25, 0.75] {
            caps.move(to: point(0.31, y))
            caps.line(to: point(0.69, y))
        }
        caps.lineWidth = s * 0.045
        caps.lineCapStyle = .round
        caps.stroke()

        for corners: [(CGFloat, CGFloat)] in [[(0.405, 0.65), (0.595, 0.65), (0.50, 0.545)],
                                             [(0.405, 0.31), (0.595, 0.31), (0.50, 0.425)]] {
            let sand = NSBezierPath()
            sand.move(to: point(corners[0].0, corners[0].1))
            for corner in corners.dropFirst() { sand.line(to: point(corner.0, corner.1)) }
            sand.close()
            sand.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
