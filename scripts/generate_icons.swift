#!/usr/bin/env swift
// Generates the app icon and menu bar template icon into Assets.xcassets.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("AniMenyu/Assets.xcassets/AppIcon.appiconset")
let menuIconDir = root.appendingPathComponent("AniMenyu/Assets.xcassets/MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func render(width: Int, height: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(ctx, CGFloat(height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Rounded triangle pointing right, centered at `center`.
func roundedTriangle(center: CGPoint, radius: CGFloat, corner: CGFloat) -> CGPath {
    let points = (0..<3).map { i -> CGPoint in
        let angle = CGFloat(i) * 2 * .pi / 3
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
    let path = CGMutablePath()
    path.move(to: CGPoint(
        x: (points[0].x + points[2].x) / 2,
        y: (points[0].y + points[2].y) / 2
    ))
    for i in 0..<3 {
        path.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % 3], radius: corner)
    }
    path.closeSubpath()
    return path
}

// MARK: - App icon

func drawAppIcon(_ ctx: CGContext, _ size: CGFloat) {
    let s = size / 1024

    // macOS squircle plate: 824x824 centered
    let plate = CGPath(
        roundedRect: CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
        cornerWidth: 185 * s, cornerHeight: 185 * s, transform: nil
    )

    ctx.saveGState()
    ctx.addPath(plate)
    ctx.clip()

    // Flat dark navy background (AniList vibes)
    ctx.setFillColor(rgb(0x151F2E))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // "AM" lettermark: blue A, pink M
    var font = NSFont.systemFont(ofSize: 380 * s, weight: .heavy)
    if let rounded = font.fontDescriptor.withDesign(.rounded) {
        font = NSFont(descriptor: rounded, size: 380 * s) ?? font
    }
    let text = NSMutableAttributedString()
    text.append(NSAttributedString(string: "A", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: rgb(0x3DB4F2))!,
        .kern: -14 * s,
    ]))
    text.append(NSAttributedString(string: "M", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: rgb(0xE85D75))!,
    ]))
    let bounds = text.size()
    text.draw(at: CGPoint(
        x: (size - bounds.width) / 2,
        y: (size - bounds.height) / 2 + 20 * s
    ))

    ctx.restoreGState()
}

// MARK: - Menu bar icon (template): flat "AM" wordmark

func drawMenuIcon(_ ctx: CGContext, _ size: CGFloat) {
    let s = size / 18
    let canvasWidth = CGFloat(ctx.width)

    var font = NSFont.systemFont(ofSize: 13.5 * s, weight: .heavy)
    if let rounded = font.fontDescriptor.withDesign(.rounded) {
        font = NSFont(descriptor: rounded, size: 13.5 * s) ?? font
    }
    let text = NSAttributedString(string: "AM", attributes: [
        .font: font,
        .foregroundColor: NSColor.black,
        .kern: -0.8 * s,
    ])
    let bounds = text.size()
    text.draw(at: CGPoint(
        x: (canvasWidth - bounds.width) / 2,
        y: (size - bounds.height) / 2
    ))
}

// MARK: - Write files

let appIconSizes: [(name: String, px: Int)] = [
    ("icon_16", 16), ("icon_32", 32), ("icon_64", 64), ("icon_128", 128),
    ("icon_256", 256), ("icon_512", 512), ("icon_1024", 1024),
]
for (name, px) in appIconSizes {
    let data = render(width: px, height: px, draw: drawAppIcon)
    try data.write(to: appIconDir.appendingPathComponent("\(name).png"))
}

try render(width: 22, height: 18, draw: drawMenuIcon).write(to: menuIconDir.appendingPathComponent("menubar_18.png"))
try render(width: 44, height: 36, draw: drawMenuIcon).write(to: menuIconDir.appendingPathComponent("menubar_36.png"))

print("Icons generated.")
