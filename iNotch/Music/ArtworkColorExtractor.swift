import AppKit
import SwiftUI

struct ColorPalette: Equatable {
    var dominant: Color
    var secondary: Color
    var highlight: Color
    var background: Color
    var glow: Color
    
    static let fallback = ColorPalette(
        dominant: Color(red: 0.98, green: 0.24, blue: 0.32),
        secondary: Color(red: 0.95, green: 0.45, blue: 0.55),
        highlight: Color(red: 1.0, green: 0.6, blue: 0.7),
        background: Color(red: 0.2, green: 0.05, blue: 0.1),
        glow: Color(red: 0.98, green: 0.24, blue: 0.32)
    )
}

/// Extracts a dynamic color palette from album artwork.
enum ArtworkColorExtractor {
    
    static func extractPalette(from image: NSImage) -> ColorPalette {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .fallback
        }

        // Downsample to a tiny bitmap
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .fallback }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Bucket by 4 bits per channel
        var buckets: [UInt16: (count: Int, r: Int, g: Int, b: Int)] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if max(r, g, b) < 20 || min(r, g, b) > 240 { continue } // ignore extreme black/white
            let key = UInt16(r >> 4) << 8 | UInt16(g >> 4) << 4 | UInt16(b >> 4)
            let entry = buckets[key] ?? (0, 0, 0, 0)
            buckets[key] = (entry.count + 1, entry.r + r, entry.g + g, entry.b + b)
        }

        // Sort by score
        let sortedBuckets = buckets.values.sorted { score($0) > score($1) }
        guard let best = sortedBuckets.first else {
            return .fallback
        }

        // Find secondary and highlight by distance from dominant
        var secondaryBucket = sortedBuckets.first(where: { distance($0, best) > 100 }) ?? best
        var highlightBucket = sortedBuckets.first(where: { distance($0, best) > 50 && distance($0, secondaryBucket) > 50 }) ?? secondaryBucket
        
        let dominantColor = toColor(best)
        let secondaryColor = toColor(secondaryBucket)
        let highlightColor = toColor(highlightBucket)

        // Adjust for visibility based on perceived luminance
        let domNS = NSColor(dominantColor).usingColorSpace(.deviceRGB) ?? NSColor(white: 0, alpha: 1)
        
        let r = domNS.redComponent
        let g = domNS.greenComponent
        let b = domNS.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        
        let isBright = luminance > 0.6
        
        let finalDominant: Color
        let finalSecondary: Color
        let finalHighlight: Color
        let finalBackground: Color
        let finalGlow: Color
        
        if isBright {
            // Dark UI on bright background
            finalDominant = Color(NSColor(
                hue: domNS.hueComponent,
                saturation: min(domNS.saturationComponent, 0.4),
                brightness: 0.15,
                alpha: 1
            ))
            let secNS = NSColor(secondaryColor).usingColorSpace(.deviceRGB) ?? domNS
            finalSecondary = Color(NSColor(
                hue: secNS.hueComponent,
                saturation: min(secNS.saturationComponent, 0.3),
                brightness: 0.25,
                alpha: 1
            ))
            let highNS = NSColor(highlightColor).usingColorSpace(.deviceRGB) ?? domNS
            finalHighlight = Color(NSColor(
                hue: highNS.hueComponent,
                saturation: min(highNS.saturationComponent, 0.5),
                brightness: 0.1,
                alpha: 1
            ))
            finalBackground = Color(NSColor(
                hue: domNS.hueComponent,
                saturation: min(domNS.saturationComponent * 0.3, 0.2),
                brightness: 0.85,
                alpha: 1
            ))
            finalGlow = finalDominant
        } else {
            // Bright UI on dark background
            finalDominant = Color(NSColor(
                hue: domNS.hueComponent,
                saturation: min(domNS.saturationComponent, 0.85),
                brightness: max(domNS.brightnessComponent, 0.85),
                alpha: 1
            ))
            let secNS = NSColor(secondaryColor).usingColorSpace(.deviceRGB) ?? domNS
            finalSecondary = Color(NSColor(
                hue: secNS.hueComponent,
                saturation: min(secNS.saturationComponent, 0.7),
                brightness: max(secNS.brightnessComponent, 0.75),
                alpha: 1
            ))
            let highNS = NSColor(highlightColor).usingColorSpace(.deviceRGB) ?? domNS
            finalHighlight = Color(NSColor(
                hue: highNS.hueComponent,
                saturation: min(highNS.saturationComponent, 0.9),
                brightness: 1.0,
                alpha: 1
            ))
            finalBackground = Color(NSColor(
                hue: domNS.hueComponent,
                saturation: min(domNS.saturationComponent * 0.5, 0.4),
                brightness: 0.15,
                alpha: 1
            ))
            finalGlow = finalDominant
        }

        return ColorPalette(
            dominant: finalDominant,
            secondary: finalSecondary,
            highlight: finalHighlight,
            background: finalBackground,
            glow: finalGlow
        )
    }

    private static func score(_ entry: (count: Int, r: Int, g: Int, b: Int)) -> Double {
        let r = Double(entry.r) / Double(entry.count)
        let g = Double(entry.g) / Double(entry.count)
        let b = Double(entry.b) / Double(entry.count)
        let hi = max(r, g, b)
        let saturation = hi > 0 ? (hi - min(r, g, b)) / hi : 0
        return Double(entry.count) * (1 + 2 * saturation)
    }
    
    private static func distance(_ a: (count: Int, r: Int, g: Int, b: Int), _ b: (count: Int, r: Int, g: Int, b: Int)) -> Double {
        let r1 = Double(a.r) / Double(a.count)
        let g1 = Double(a.g) / Double(a.count)
        let b1 = Double(a.b) / Double(a.count)
        let r2 = Double(b.r) / Double(b.count)
        let g2 = Double(b.g) / Double(b.count)
        let b2 = Double(b.b) / Double(b.count)
        return sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2))
    }
    
    private static func toColor(_ bucket: (count: Int, r: Int, g: Int, b: Int)) -> Color {
        Color(
            red: Double(bucket.r) / Double(bucket.count) / 255.0,
            green: Double(bucket.g) / Double(bucket.count) / 255.0,
            blue: Double(bucket.b) / Double(bucket.count) / 255.0
        )
    }
}
