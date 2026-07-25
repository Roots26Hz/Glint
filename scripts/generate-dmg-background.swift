#!/usr/bin/env swift
//
// Renders the Glint DMG window background: ink-dark glass, aurora glows,
// the hand-written Glint wordmark, a notch silhouette along the top edge,
// and a drag arrow between the app and Applications drop positions.
// Writes dist/dmg-background.png (1320×840 px tagged as 660×420 pt so
// Finder renders it Retina-crisp). Run from anywhere:
//
//   swift scripts/generate-dmg-background.swift

import AppKit

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outURL = repoRoot.appendingPathComponent("dist/dmg-background.png")

let W: CGFloat = 660, H: CGFloat = 420, SCALE: CGFloat = 2

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W * SCALE), pixelsHigh: Int(H * SCALE),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: W, height: H) // 144 dpi → Retina points

NSGraphicsContext.saveGraphicsState()
// rep.size (660×420 pt over 1320×840 px) already bakes the 2× user-space
// scale into this context — draw in points, no manual scaling.
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
defer { NSGraphicsContext.restoreGraphicsState() }

func rgba(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: a
    )
}

// ---- Ground: ink gradient ----
let full = NSRect(x: 0, y: 0, width: W, height: H)
NSGradient(starting: rgba(0x141824), ending: rgba(0x05060B))!.draw(in: full, angle: -90)

// ---- Aurora glows (cool accents + one warm ember) ----
func glow(_ center: NSPoint, _ radius: CGFloat, _ color: NSColor) {
    let g = NSGradient(starting: color, ending: color.withAlphaComponent(0))!
    g.draw(
        fromCenter: center, radius: 0,
        toCenter: center, radius: radius,
        options: []
    )
}
glow(NSPoint(x: 130, y: 340), 260, rgba(0x5FD6FF, 0.16))
glow(NSPoint(x: 560, y: 300), 240, rgba(0x9D8BFF, 0.15))
glow(NSPoint(x: 330, y: 40), 220, rgba(0xE0AC58, 0.07))

// ---- "Glint." wordmark: real typeface (SnellRoundhand Black) with the
// hello gradient and a graduated glow, built from glyph outlines ----
import CoreText

func glyphPath(_ string: String, font: NSFont) -> CGPath {
    let attr = NSAttributedString(string: string, attributes: [.font: font])
    let line = CTLineCreateWithAttributedString(attr)
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let f = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for i in 0..<CTRunGetGlyphCount(run) {
            var g = CGGlyph(); var pos = CGPoint()
            CTRunGetGlyphs(run, CFRangeMake(i, 1), &g)
            CTRunGetPositions(run, CFRangeMake(i, 1), &pos)
            if let gp = CTFontCreatePathForGlyph(f, g, nil) {
                path.addPath(gp, transform: CGAffineTransform(translationX: pos.x, y: pos.y))
            }
        }
    }
    return path
}

let markFont = NSFont(name: "SnellRoundhand-Black", size: 50)!
let rawMark = glyphPath("glint", font: markFont)
let markBounds = rawMark.boundingBoxOfPath
var center = CGAffineTransform(
    translationX: (W - markBounds.width) / 2 - markBounds.minX,
    y: H - 182 - markBounds.minY
)
let markCG = rawMark.copy(using: &center)!
let markRect = markCG.boundingBoxOfPath
let helloColors: [NSColor] = [
    rgba(0x3BF5A6), rgba(0x4FD8FF), rgba(0x8B5CFF),
]
let helloGradient = NSGradient(
    colorsAndLocations: (helloColors[0], 0.0), (helloColors[1], 0.5), (helloColors[2], 1.0)
)!
let cg = NSGraphicsContext.current!.cgContext
/// Fills the glyphs (grown by `spread`) with the gradient at `alpha` —
/// concentric passes read as a soft neon glow.
func helloPass(spread: CGFloat, alpha: CGFloat) {
    cg.saveGState()
    cg.setAlpha(alpha)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.addPath(markCG)
    if spread > 0 {
        cg.addPath(markCG.copy(
            strokingWithWidth: spread * 2, lineCap: .round, lineJoin: .round, miterLimit: 10
        ))
    }
    cg.clip(using: .winding)
    helloGradient.draw(in: markRect.insetBy(dx: -spread - 4, dy: -spread - 4), angle: 0)
    cg.endTransparencyLayer()
    cg.restoreGState()
}
helloPass(spread: 10, alpha: 0.05)
helloPass(spread: 6.5, alpha: 0.09)
helloPass(spread: 4, alpha: 0.14)
helloPass(spread: 2, alpha: 0.22)
helloPass(spread: 0, alpha: 1.0)

// ---- the app icon itself, floating above the wordmark ----
if let iconImg = NSImage(contentsOf: repoRoot.appendingPathComponent(
    "Glint/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png")) {
    iconImg.draw(in: NSRect(x: (W - 84) / 2, y: H - 124, width: 84, height: 84),
                 from: .zero, operation: .sourceOver, fraction: 1.0)
}

// ---- Tagline ----
func drawCentered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: kern,
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(x: (W - sz.width) / 2, y: y))
}


// ---- Drag arrow between icon slots (icons sit at x 165 / 495, y 220 from top) ----
// In AppKit coords the icon row centers at y = H - 220 = 200.
let arrowY: CGFloat = 200
let arrow = NSBezierPath()
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 258, y: arrowY))
arrow.curve(
    to: NSPoint(x: 402, y: arrowY),
    controlPoint1: NSPoint(x: 306, y: arrowY + 26),
    controlPoint2: NSPoint(x: 354, y: arrowY + 26)
)
NSColor.white.withAlphaComponent(0.45).setStroke()
arrow.stroke()
let head = NSBezierPath()
head.lineWidth = 3
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: 390, y: arrowY + 11))
head.line(to: NSPoint(x: 404, y: arrowY + 0.5))
head.line(to: NSPoint(x: 391, y: arrowY - 9))
NSColor.white.withAlphaComponent(0.45).setStroke()
head.stroke()

drawCentered("drag Glint into Applications", y: arrowY - 88, size: 12, weight: .regular,
             color: NSColor.white.withAlphaComponent(0.5))
drawCentered("first open: System Settings → Privacy & Security → Open Anyway  ·  see HOW TO INSTALL", y: 18,
             size: 9, weight: .regular, color: NSColor.white.withAlphaComponent(0.32))

// ---- Faint grain so the gradient doesn't band ----
srand48(7)
NSColor.white.withAlphaComponent(0.02).setFill()
for _ in 0..<2600 {
    NSRect(x: CGFloat(drand48()) * W, y: CGFloat(drand48()) * H, width: 0.7, height: 0.7).fill()
}

try FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true
)
try rep.representation(using: .png, properties: [:])!.write(to: outURL)
print("wrote \(outURL.path)")
