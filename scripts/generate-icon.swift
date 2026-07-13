#!/usr/bin/env swift
//
// Renders the Glint app icon and writes every size the asset catalog needs,
// plus docs/icon.png for the README and the monochrome menu-bar template
// glyph (MenuBarIcon imageset). Run from anywhere:
//
//   swift scripts/generate-icon.swift
//
// Design: dark glassy macOS squircle, a MacBook-notch silhouette hanging from
// the top, and glowing gradient equalizer bars beneath it.

import AppKit

// MARK: - Paths

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let appIconSet = repoRoot.appendingPathComponent(
    "Glint/Resources/Assets.xcassets/AppIcon.appiconset"
)
let docsDir = repoRoot.appendingPathComponent("docs")

// MARK: - Drawing helpers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func makeRep(_ pixels: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

// MARK: - Master render (1024 pt)

func renderMaster() -> NSBitmapImageRep {
    let rep = makeRep(1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Apple's macOS icon grid: 1024 canvas, ~824 pt content squircle,
    // the rest transparent margin (the system adds no mask of its own).
    let content = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: content, xRadius: 185, yRadius: 185)

    // Soft drop shadow behind the slab.
    NSGraphicsContext.current?.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowOffset = NSSize(width: 0, height: -12)
    drop.shadowBlurRadius = 24
    drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
    drop.set()
    color(0x14171E).setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()

    // Dark slate glass, lighter toward the top.
    NSGradient(starting: color(0x0B0D12), ending: color(0x2A2F3B))!
        .draw(in: content, angle: 90)

    // Notch silhouette hanging from the top edge. The rect pokes above the
    // clip so only its bottom corners render rounded, like the real bezel.
    let notchWidth: CGFloat = 400
    let notch = NSBezierPath(
        roundedRect: NSRect(
            x: content.midX - notchWidth / 2, y: content.maxY - 92,
            width: notchWidth, height: 92 + 60
        ),
        xRadius: 34, yRadius: 34
    )
    NSColor.black.setFill()
    notch.fill()

    // Equalizer bars: capsules of varied height on a shared baseline.
    let barWidths: CGFloat = 74
    let gap: CGFloat = 34
    let heights: [CGFloat] = [165, 275, 375, 240, 190]
    let baseline: CGFloat = 240
    let totalWidth = CGFloat(heights.count) * barWidths + CGFloat(heights.count - 1) * gap
    var x = content.midX - totalWidth / 2

    let bars = NSBezierPath()
    for height in heights {
        bars.append(NSBezierPath(
            roundedRect: NSRect(x: x, y: baseline, width: barWidths, height: height),
            xRadius: barWidths / 2, yRadius: barWidths / 2
        ))
        x += barWidths + gap
    }

    // Glow pass: blurred shadow around solid fills, then the crisp
    // gradient pass on top. One gradient spans all bars so taller bars
    // reach further into the violet.
    NSGraphicsContext.current?.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowOffset = .zero
    glow.shadowBlurRadius = 52
    glow.shadowColor = color(0x5B7CFA, 0.85)
    glow.set()
    color(0x38BDF8).setFill()
    bars.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    bars.addClip()
    let barRegion = NSRect(
        x: content.midX - totalWidth / 2, y: baseline,
        width: totalWidth, height: heights.max()!
    )
    NSGradient(starting: color(0x22D3EE), ending: color(0xA78BFA))!
        .draw(in: barRegion, angle: 90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // The glint: a four-point sparkle catching the light off the tallest bar.
    func sparklePath(cx: CGFloat, cy: CGFloat, r: CGFloat) -> NSBezierPath {
        let pinch = r * 0.16
        let path = NSBezierPath()
        path.move(to: NSPoint(x: cx, y: cy + r))
        path.curve(to: NSPoint(x: cx + r, y: cy),
                   controlPoint1: NSPoint(x: cx + pinch, y: cy + pinch),
                   controlPoint2: NSPoint(x: cx + pinch, y: cy + pinch))
        path.curve(to: NSPoint(x: cx, y: cy - r),
                   controlPoint1: NSPoint(x: cx + pinch, y: cy - pinch),
                   controlPoint2: NSPoint(x: cx + pinch, y: cy - pinch))
        path.curve(to: NSPoint(x: cx - r, y: cy),
                   controlPoint1: NSPoint(x: cx - pinch, y: cy - pinch),
                   controlPoint2: NSPoint(x: cx - pinch, y: cy - pinch))
        path.curve(to: NSPoint(x: cx, y: cy + r),
                   controlPoint1: NSPoint(x: cx - pinch, y: cy + pinch),
                   controlPoint2: NSPoint(x: cx - pinch, y: cy + pinch))
        path.close()
        return path
    }
    NSGraphicsContext.current?.saveGraphicsState()
    let sparkleGlow = NSShadow()
    sparkleGlow.shadowOffset = .zero
    sparkleGlow.shadowBlurRadius = 34
    sparkleGlow.shadowColor = NSColor.white.withAlphaComponent(0.9)
    sparkleGlow.set()
    NSColor.white.setFill()
    sparklePath(cx: content.midX + 208, cy: baseline + 420, r: 58).fill()
    sparklePath(cx: content.midX + 268, cy: baseline + 330, r: 26).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Glass highlight washing down from the top edge.
    NSGradient(
        starting: NSColor.white.withAlphaComponent(0.13),
        ending: NSColor.white.withAlphaComponent(0)
    )!.draw(
        in: NSRect(x: content.minX, y: content.maxY - 310, width: content.width, height: 310),
        angle: -90
    )

    // Faint inner border keeps the slab defined at small sizes.
    NSColor.white.withAlphaComponent(0.08).setStroke()
    let border = NSBezierPath(
        roundedRect: content.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183
    )
    border.lineWidth = 4
    border.stroke()

    NSGraphicsContext.current?.restoreGraphicsState()
    return rep
}

// MARK: - Downsample + write

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}

let master = renderMaster()
let masterImage = NSImage(size: NSSize(width: 1024, height: 1024))
masterImage.addRepresentation(master)

func downsample(to pixels: Int) -> NSBitmapImageRep {
    let rep = makeRep(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    masterImage.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero, operation: .copy, fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = size == 1024 ? master : downsample(to: size)
    let url = appIconSet.appendingPathComponent("icon_\(size).png")
    try writePNG(rep, to: url)
    print("wrote \(url.path)")
}

try writePNG(master, to: docsDir.appendingPathComponent("icon.png"))
print("wrote \(docsDir.appendingPathComponent("icon.png").path)")

// MARK: - Menu-bar template glyph

// Same mark (notch + bars) as pure black alpha shapes; the asset is flagged
// template so the menu bar tints it for light/dark/selected states.
func renderMenuGlyph(_ pixels: Int) -> NSBitmapImageRep {
    let rep = makeRep(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(pixels) / 36 // designed on a 36 px (@2x) grid
    NSColor.black.setFill()

    // Notch hanging from the top edge; the rect pokes above the canvas so
    // only its bottom corners render rounded.
    let notchWidth = 22 * s
    NSBezierPath(
        roundedRect: NSRect(
            x: (CGFloat(pixels) - notchWidth) / 2, y: 30 * s,
            width: notchWidth, height: 12 * s
        ),
        xRadius: 3 * s, yRadius: 3 * s
    ).fill()

    // Equalizer capsules on a shared baseline.
    let barWidth = 4 * s
    let gap = 2 * s
    let heights: [CGFloat] = [12, 19, 25, 16, 13]
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = (CGFloat(pixels) - totalWidth) / 2
    for height in heights {
        NSBezierPath(
            roundedRect: NSRect(x: x, y: 1 * s, width: barWidth, height: height * s),
            xRadius: barWidth / 2, yRadius: barWidth / 2
        ).fill()
        x += barWidth + gap
    }
    return rep
}

let menuIconSet = repoRoot.appendingPathComponent(
    "Glint/Resources/Assets.xcassets/MenuBarIcon.imageset"
)
try FileManager.default.createDirectory(at: menuIconSet, withIntermediateDirectories: true)
let menuContents = """
{
  "images" : [
    { "filename" : "menubar_18.png", "idiom" : "mac", "scale" : "1x" },
    { "filename" : "menubar_36.png", "idiom" : "mac", "scale" : "2x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}
"""
try menuContents.write(
    to: menuIconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8
)
for pixels in [18, 36] {
    let url = menuIconSet.appendingPathComponent("menubar_\(pixels == 18 ? 18 : 36).png")
    try writePNG(renderMenuGlyph(pixels), to: url)
    print("wrote \(url.path)")
}
