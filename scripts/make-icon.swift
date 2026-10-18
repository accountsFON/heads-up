// Draws the Heads Up app icon (a bell with a badge) into an .iconset folder.
//   swiftc -o build/make-icon scripts/make-icon.swift && build/make-icon build/AppIcon.iconset
//   iconutil -c icns build/AppIcon.iconset -o AppIcon.icns
// Plain CoreGraphics paths, so it runs headless on CI and ships no third party artwork.
import CoreGraphics
import Foundation
import ImageIO

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws the icon on a 1024 point canvas (origin bottom left).
func draw(_ ctx: CGContext) {
    // Background tile on the standard macOS icon grid: 824 points with a 100 point margin.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x2F3FBF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0x6A7BFF), color(0x2F2A9E)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Bell body.
    let bell = CGMutablePath()
    bell.move(to: CGPoint(x: 262, y: 360))
    bell.addCurve(to: CGPoint(x: 352, y: 600), control1: CGPoint(x: 330, y: 420), control2: CGPoint(x: 352, y: 490))
    bell.addCurve(to: CGPoint(x: 512, y: 770), control1: CGPoint(x: 352, y: 710), control2: CGPoint(x: 425, y: 770))
    bell.addCurve(to: CGPoint(x: 672, y: 600), control1: CGPoint(x: 599, y: 770), control2: CGPoint(x: 672, y: 710))
    bell.addCurve(to: CGPoint(x: 762, y: 360), control1: CGPoint(x: 672, y: 490), control2: CGPoint(x: 694, y: 420))
    bell.closeSubpath()
    // Rim, knob, and clapper.
    let parts: [CGPath] = [
        bell,
        CGPath(roundedRect: CGRect(x: 232, y: 318, width: 560, height: 64),
               cornerWidth: 32, cornerHeight: 32, transform: nil),
        CGPath(ellipseIn: CGRect(x: 476, y: 752, width: 72, height: 72), transform: nil),
        CGPath(ellipseIn: CGRect(x: 446, y: 214, width: 132, height: 132), transform: nil),
    ]

    // One transparency layer so the overlapping shapes cast a single shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x10104A, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color(0xFFFFFF))
    for shape in parts {
        ctx.addPath(shape)
        ctx.fillPath()
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Badge: a red dot inside a ring of the tile gradient, so it reads cut out of the bell.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: 618, y: 640, width: 236, height: 236))
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()
    ctx.addEllipse(in: CGRect(x: 644, y: 666, width: 184, height: 184))
    ctx.setFillColor(color(0xFF453A))
    ctx.fillPath()
}

func writePNG(size: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(ctx)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(size: base, to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(size: base * 2, to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
