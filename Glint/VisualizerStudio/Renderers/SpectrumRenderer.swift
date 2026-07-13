import SwiftUI

struct SpectrumRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let bars = settings.barCount
        let levels = data.levels(for: bars)
        
        let spacing: CGFloat = 3.0
        let totalSpacing = spacing * CGFloat(bars - 1)
        
        let barWidth = (size.width - totalSpacing) / CGFloat(bars)
        let actualThickness = barWidth * CGFloat(0.5 + (settings.thickness * 0.5))
        
        var paths = Path()
        
        for i in 0..<bars {
            let level = CGFloat(levels[i])
            let adjustedLevel = min(1.0, level * CGFloat(settings.sensitivity * 2.0))
            let barHeight = max(2, adjustedLevel * size.height * CGFloat(settings.waveHeight * 2.0))
            
            let x = CGFloat(i) * (barWidth + spacing) + (barWidth - actualThickness) / 2
            
            // If center out animation is enabled, scale from center Y instead of bottom
            let y = settings.centerOutAnimation ? (size.height - barHeight) / 2 : size.height - barHeight
            
            let cornerRad = CGSize(width: actualThickness/2 * CGFloat(settings.cornerRadius * 2), height: actualThickness/2 * CGFloat(settings.cornerRadius * 2))
            let bgRect = CGRect(x: x, y: y, width: actualThickness, height: barHeight)
            let path = Path(roundedRect: bgRect, cornerSize: cornerRad)
            
            let color = resolveColor(palette: palette, settings: settings)
            let highlight = resolveHighlight(palette: palette, settings: settings)
            
            let gradient = Gradient(colors: [highlight, color])
            
            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: 3.0 * CGFloat(settings.glowStrength * 2.0)))
                ctx.fill(path, with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + barHeight)))
            }
            
            context.drawLayer { ctx in
                ctx.fill(path, with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + barHeight)))
            }
        }
    }
}
