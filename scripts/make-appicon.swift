// Draws the three iOS app icons (light, dark, tinted) into Sources/Assets.xcassets/AppIcon.appiconset.
//   swift scripts/make-appicon.swift Sources/Assets.xcassets/AppIcon.appiconset
// The same lily as Lily-macos (AppIconArt.swift): three pointed petals on a soft gradient. iOS icons are
// full-bleed squares (the system rounds them), and the mark is drawn large so it reads at small sizes.
import AppKit

let markScale: CGFloat = 1.34 // the lily's size relative to the Mac icon

func render(top: (CGFloat, CGFloat, CGFloat), bottom: (CGFloat, CGFloat, CGFloat), glow: CGFloat, petal: CGFloat, to url: URL) throws {
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    // An opaque bitmap (no alpha channel): App Store icons must not have one.
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let colors = [NSColor(srgbRed: top.0, green: top.1, blue: top.2, alpha: 1).cgColor,
                  NSColor(srgbRed: bottom.0, green: bottom.1, blue: bottom.2, alpha: 1).cgColor] as CFArray
    ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: colors, locations: [0, 1])!, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let light = CGGradient(colorsSpace: srgb, colors: [NSColor(white: 1, alpha: glow).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(light, startCenter: CGPoint(x: 512, y: 1060), startRadius: 0, endCenter: CGPoint(x: 512, y: 1060), endRadius: 760, options: [])

    func petalPath(angle: CGFloat, length: CGFloat, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: 0, y: length), control1: CGPoint(x: width * 1.25, y: length * 0.28), control2: CGPoint(x: width * 0.7, y: length * 0.78))
        path.addCurve(to: .zero, control1: CGPoint(x: -width * 0.7, y: length * 0.78), control2: CGPoint(x: -width * 1.25, y: length * 0.28))
        path.closeSubpath()
        return path.copy(using: [CGAffineTransform(rotationAngle: -angle)])!
    }
    // The Mac drawing puts the lily's base at (512, 262) and its tip at 762: scale about the canvas centre.
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: markScale, y: markScale)
    ctx.translateBy(x: -512, y: -512)
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
    let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: url)
}

guard CommandLine.arguments.count == 2 else { FileHandle.standardError.write(Data("usage: make-appicon <AppIcon.appiconset>\n".utf8)); exit(64) }
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try render(top: (0.56, 0.60, 1.00), bottom: (0.27, 0.24, 0.86), glow: 0.22, petal: 1, to: dir.appendingPathComponent("AppIcon.png"))
try render(top: (0.31, 0.33, 0.66), bottom: (0.10, 0.09, 0.34), glow: 0.10, petal: 0.93, to: dir.appendingPathComponent("AppIcon-dark.png"))
try render(top: (0.24, 0.24, 0.24), bottom: (0.05, 0.05, 0.05), glow: 0.06, petal: 1, to: dir.appendingPathComponent("AppIcon-tinted.png"))
