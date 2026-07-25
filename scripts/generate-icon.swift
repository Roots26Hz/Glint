#!/usr/bin/env swift
//
// Builds the Glint app icon from the master artwork
// (docs/GLINTLOGOANDARTWORK.png): the neon "gl" squircle is cropped out,
// composited onto a transparent 1024 canvas on Apple's icon grid, and
// written at every size the asset catalog needs, plus docs/icon.png and the
// monochrome MenuBarIcon template derived from the monogram's luminance.
// Run from anywhere:
//
//   swift scripts/generate-icon.swift

import AppKit

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let artURL = repoRoot.appendingPathComponent("docs/GLINTLOGOANDARTWORK.png")
let appIconSet = repoRoot.appendingPathComponent("Glint/Resources/Assets.xcassets/AppIcon.appiconset")
let menuBarSet = repoRoot.appendingPathComponent("Glint/Resources/Assets.xcassets/MenuBarIcon.imageset")
let docsDir = repoRoot.appendingPathComponent("docs")

guard let art = NSImage(contentsOf: artURL),
      let artRep = NSBitmapImageRep(data: art.tiffRepresentation!),
      let artCG = artRep.cgImage else { fatalError("artwork missing") }
let AW = CGFloat(artRep.pixelsWide), AH = CGFloat(artRep.pixelsHigh)

// The icon squircle in the artwork (measured from the master):
// centered at ~ (0.4986 W, 0.4148 H), side ~ 0.288 W.
let side = 0.288 * AW
let iconRectSrc = CGRect(x: 0.4986 * AW - side/2, y: 0.4148 * AH - side/2,
                         width: side, height: side)

func makeRep(_ px: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

// ---- master 1024 icon: artwork crop clipped to the standard squircle ----
func renderMaster() -> NSBitmapImageRep {
    let rep = makeRep(1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .high

    // Apple grid: 824pt content squircle, corner radius ≈ 185, margin transparent.
    let content = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: content, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.addPath(squircle)
    ctx.clip()

    // Map the artwork's icon rect onto the content rect (slight overscan so
    // the neon rim reaches the clipped edge cleanly).
    let over: CGFloat = 1.02
    let s = content.width * over / iconRectSrc.width
    // artwork pixel coords are top-left origin; CG canvas is bottom-left.
    let dx = content.midX - (iconRectSrc.midX) * s
    let dy = content.midY - (AH - iconRectSrc.midY) * s
    ctx.draw(artCG, in: CGRect(x: dx, y: dy, width: AW * s, height: AH * s))
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, _ url: URL) {
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.lastPathComponent)")
}

let master = renderMaster()
let masterImage = NSImage(size: NSSize(width: 1024, height: 1024))
masterImage.addRepresentation(master)

func downsample(_ px: Int) -> NSBitmapImageRep {
    let rep = makeRep(px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    masterImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(px == 1024 ? master : downsample(px), appIconSet.appendingPathComponent("icon_\(px).png"))
}
writePNG(master, docsDir.appendingPathComponent("icon.png"))

// ---- MenuBarIcon: crisp vector soundwave template ----
// The old glyph was sampled from the artwork's luminance, so it arrived at
// the menu bar soft and blurry. Instead we draw a clean equalizer/soundwave
// mark — five rounded bars in a symmetric profile — as pure black + alpha at
// the exact target pixel size. Tagged as a template image, macOS tints it to
// the menu-bar colour (crisp white on the dark bar) and it never blurs.
func renderMenuBar(_ px: Int) -> NSBitmapImageRep {
    let rep = makeRep(px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

    let P = CGFloat(px)
    let heights: [CGFloat] = [0.42, 0.72, 1.0, 0.72, 0.42]  // centered soundwave
    let n = CGFloat(heights.count)
    let inset = P * 0.10                       // side / top / bottom breathing room
    let usableW = P - inset * 2
    let usableH = P - inset * 2
    let gapRatio: CGFloat = 0.55               // gap as a fraction of bar width
    let barW = usableW / (n + (n - 1) * gapRatio)
    let gap = barW * gapRatio
    let r = barW / 2
    for (i, h) in heights.enumerated() {
        let bh = max(barW, usableH * h)
        let x = inset + CGFloat(i) * (barW + gap)
        let y = (P - bh) / 2                    // vertically centered
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: barW, height: bh),
                           cornerWidth: r, cornerHeight: r, transform: nil))
    }
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}
writePNG(renderMenuBar(18), menuBarSet.appendingPathComponent("menubar_18.png"))
writePNG(renderMenuBar(36), menuBarSet.appendingPathComponent("menubar_36.png"))
print("done")
