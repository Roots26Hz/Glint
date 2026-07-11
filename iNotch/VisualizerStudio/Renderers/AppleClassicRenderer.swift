import SwiftUI

struct AppleClassicRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let bars = settings.barCount
        let levels = data.levels(for: bars)
        
        let spacing: CGFloat = 2.5
        let totalSpacing = spacing * CGFloat(bars - 1)
        
        // Background layer is thick
        let bgBarWidth = (size.width - totalSpacing) / CGFloat(bars)
        let actualThickness = bgBarWidth * CGFloat(0.5 + (settings.thickness * 0.5)) // Scale by thickness setting
        
        // Foreground layer is thinner and sharp
        let fgBarWidth = max(1, actualThickness - 1.5)
        
        var bgPaths = Path()
        var fgPaths = Path()
        
        for i in 0..<bars {
            let level = CGFloat(levels[i])
            // Apply sensitivity and waveHeight
            let adjustedLevel = min(1.0, level * CGFloat(settings.sensitivity * 2.0))
            let barHeight = max(2, adjustedLevel * size.height * CGFloat(settings.waveHeight * 2.0))
            
            let x = CGFloat(i) * (bgBarWidth + spacing) + (bgBarWidth - actualThickness) / 2
            let y = size.height - barHeight
            
            let cornerRad = CGSize(width: actualThickness/2 * CGFloat(settings.cornerRadius * 2), height: actualThickness/2 * CGFloat(settings.cornerRadius * 2))
            let fgCornerRad = CGSize(width: fgBarWidth/2 * CGFloat(settings.cornerRadius * 2), height: fgBarWidth/2 * CGFloat(settings.cornerRadius * 2))
            
            // Background path
            let bgRect = CGRect(x: x, y: y, width: actualThickness, height: barHeight)
            bgPaths.addRoundedRect(in: bgRect, cornerSize: cornerRad)
            
            // Foreground path (centered within the background bar)
            let fgX = x + (actualThickness - fgBarWidth) / 2
            let fgRect = CGRect(x: fgX, y: y, width: fgBarWidth, height: barHeight)
            fgPaths.addRoundedRect(in: fgRect, cornerSize: fgCornerRad)
        }
        
        let color = resolveColor(palette: palette, settings: settings)
        
        // 1. Background Bloom
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 4.0 * CGFloat(settings.glowStrength * 2.0)))
            ctx.fill(bgPaths, with: .color(color.opacity(0.6 * settings.opacity)))
        }
        
        // 2. Background Core
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 1.0 * CGFloat(settings.glowStrength * 2.0)))
            ctx.fill(bgPaths, with: .color(color.opacity(0.85 * settings.opacity)))
        }
        
        // 3. Foreground Crisp Highlights
        context.drawLayer { ctx in
            ctx.fill(fgPaths, with: .color(resolveHighlight(palette: palette, settings: settings).opacity(settings.opacity)))
        }
    }
}

// Helper to resolve colors based on settings
func resolveColor(palette: ColorPalette, settings: VisualizerSettings) -> Color {
    return palette.dominant
}

func resolveHighlight(palette: ColorPalette, settings: VisualizerSettings) -> Color {
    return palette.highlight
}
