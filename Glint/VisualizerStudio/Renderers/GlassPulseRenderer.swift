import SwiftUI

struct GlassPulseRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let bars = settings.barCount
        let levels = data.levels(for: bars)
        
        let spacing: CGFloat = 4.0
        let totalSpacing = spacing * CGFloat(bars - 1)
        
        let barWidth = (size.width - totalSpacing) / CGFloat(bars)
        let actualThickness = barWidth * CGFloat(0.5 + (settings.thickness * 0.5))
        
        var paths = Path()
        
        for i in 0..<bars {
            let level = CGFloat(levels[i])
            let adjustedLevel = min(1.0, level * CGFloat(settings.sensitivity * 2.0))
            let barHeight = max(2, adjustedLevel * size.height * CGFloat(settings.waveHeight * 2.0))
            
            let x = CGFloat(i) * (barWidth + spacing) + (barWidth - actualThickness) / 2
            let y = size.height - barHeight
            
            let cornerRad = CGSize(width: actualThickness/2 * CGFloat(settings.cornerRadius * 2), height: actualThickness/2 * CGFloat(settings.cornerRadius * 2))
            
            let bgRect = CGRect(x: x, y: y, width: actualThickness, height: barHeight)
            paths.addRoundedRect(in: bgRect, cornerSize: cornerRad)
        }
        
        let color = resolveColor(palette: palette, settings: settings)
        
        // 1. Glass back layer
        context.drawLayer { ctx in
            ctx.fill(paths, with: .color(.white.opacity(0.1 * settings.opacity)))
        }
        
        // 2. Translucent color fill
        context.drawLayer { ctx in
            ctx.blendMode = .plusLighter
            ctx.fill(paths, with: .color(color.opacity(0.4 * settings.opacity)))
        }
        
        // 3. Inner reflection/pulse
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 2.0 * CGFloat(settings.glowStrength * 2.0)))
            let pulseOpacity = (sin(time * settings.animationSpeed * 5.0) * 0.5 + 0.5) * settings.reflectionIntensity
            ctx.fill(paths, with: .color(resolveHighlight(palette: palette, settings: settings).opacity(pulseOpacity * settings.opacity)))
        }
        
        // 4. Glass border
        context.stroke(paths, with: .color(.white.opacity(0.3 * settings.opacity)), lineWidth: 1.0)
    }
}
