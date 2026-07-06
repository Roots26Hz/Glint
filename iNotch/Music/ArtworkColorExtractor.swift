import AppKit
import SwiftUI

/// Extracts a single accent color from album artwork, biased toward vibrant
/// hues and clamped for legibility against the black notch.
enum ArtworkColorExtractor {
    /// Apple Music red — used when there is no artwork or extraction fails.
    static let fallback = Color(red: 0.98, green: 0.24, blue: 0.32)

    static func dominantColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return fallback
        }

        // Downsample to a tiny bitmap; exact pixels don't matter for an accent.
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return fallback }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Bucket by 4 bits per channel; score by count weighted toward
        // saturated colors so vibrant hues beat large gray backgrounds.
        var buckets: [UInt16: (count: Int, r: Int, g: Int, b: Int)] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if max(r, g, b) < 40 || min(r, g, b) > 225 { continue } // near-black / near-white
            let key = UInt16(r >> 4) << 8 | UInt16(g >> 4) << 4 | UInt16(b >> 4)
            let entry = buckets[key] ?? (0, 0, 0, 0)
            buckets[key] = (entry.count + 1, entry.r + r, entry.g + g, entry.b + b)
        }

        guard let best = buckets.values.max(by: { score($0) < score($1) }) else {
            return fallback
        }

        let color = NSColor(
            red: CGFloat(best.r) / CGFloat(best.count) / 255,
            green: CGFloat(best.g) / CGFloat(best.count) / 255,
            blue: CGFloat(best.b) / CGFloat(best.count) / 255,
            alpha: 1
        )
        // Clamp for legibility on the black notch: bright enough to read,
        // not so saturated that thin bars vibrate.
        return Color(NSColor(
            hue: color.hueComponent,
            saturation: min(color.saturationComponent, 0.85),
            brightness: max(color.brightnessComponent, 0.55),
            alpha: 1
        ))
    }

    private static func score(_ entry: (count: Int, r: Int, g: Int, b: Int)) -> Double {
        let r = Double(entry.r) / Double(entry.count)
        let g = Double(entry.g) / Double(entry.count)
        let b = Double(entry.b) / Double(entry.count)
        let hi = max(r, g, b)
        let saturation = hi > 0 ? (hi - min(r, g, b)) / hi : 0
        return Double(entry.count) * (1 + 2 * saturation)
    }
}
