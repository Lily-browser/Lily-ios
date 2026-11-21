import AppKit

// Writes the iOS app icon PNGs (run on a Mac: `swift scripts/make-icon.swift <output dir>`).
// Same lily as Lily-macos (core/Sources/LilyCore/UI/AppIconArt.swift, default "iris" colours),
// but full-bleed: iOS masks the corners itself, so there is no tile, margin or drop shadow.
// Writes AppIcon.png (light), AppIcon-dark.png and AppIcon-tinted.png (greyscale for tinting).

enum Style { case light, dark, tinted }

func png(_ style: Style) -> Data {
    let pixels = 1024
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    // No alpha channel: the App Store rejects icons with transparency.
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    let top: NSColor, bottom: NSColor, petal: CGFloat, glow: CGFloat
    switch style {
    case .light: (top, bottom, petal, glow) = (NSColor(srgbRed: 0.56, green: 0.60, blue: 1.00, alpha: 1), NSColor(srgbRed: 0.27, green: 0.24, blue: 0.86, alpha: 1), 1, 0.22)
    case .dark: (top, bottom, petal, glow) = (NSColor(srgbRed: 0.31, green: 0.33, blue: 0.66, alpha: 1), NSColor(srgbRed: 0.10, green: 0.09, blue: 0.34, alpha: 1), 0.93, 0.10)
    case .tinted: (top, bottom, petal, glow) = (NSColor(white: 0.30, alpha: 1), NSColor(white: 0.06, alpha: 1), 1, 0)
    }

    // Opaque background, slightly lighter at the top.
    let gradient = CGGradient(colorsSpace: srgb, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
    if glow > 0 {
        let g = CGGradient(colorsSpace: srgb, colors: [NSColor(white: 1, alpha: glow).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: 512, y: 1060), startRadius: 0, endCenter: CGPoint(x: 512, y: 1060), endRadius: 700, options: [])
    }

    // The lily: three pointed petals fanning out from one point (same geometry as the Mac icon).
    func petalPath(angle: CGFloat, length: CGFloat, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: 0, y: length), control1: CGPoint(x: width * 1.25, y: length * 0.28), control2: CGPoint(x: width * 0.7, y: length * 0.78))
        path.addCurve(to: .zero, control1: CGPoint(x: -width * 0.7, y: length * 0.78), control2: CGPoint(x: -width * 1.25, y: length * 0.28))
        path.closeSubpath()
        return path.copy(using: [CGAffineTransform(rotationAngle: -angle)])!
    }
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 262)
    for (angle, length, alpha, width) in [(CGFloat.pi * 0.21, CGFloat(420), CGFloat(0.70), CGFloat(112)),
                                          (-CGFloat.pi * 0.21, CGFloat(420), CGFloat(0.70), CGFloat(112)),
                                          (0, CGFloat(500), CGFloat(1), CGFloat(132))] {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: NSColor.black.withAlphaComponent(0.16).cgColor)
        ctx.addPath(petalPath(angle: angle, length: length, width: width))
        ctx.setFillColor(NSColor(white: petal, alpha: alpha).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest))
    return data as Data
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift <output dir>\n".utf8))
    exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for (name, style) in [("AppIcon.png", Style.light), ("AppIcon-dark.png", .dark), ("AppIcon-tinted.png", .tinted)] {
    try png(style).write(to: out.appendingPathComponent(name))
}
