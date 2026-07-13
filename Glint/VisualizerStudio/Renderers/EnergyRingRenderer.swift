import SwiftUI

struct EnergyRingRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // Reduce base radius so it fits comfortably within the height (usually 24pt)
        let baseRadius = min(size.width, size.height) / 6.0 * CGFloat(1.0 + (settings.beatPulseStrength * Double(data.beatImpulse)))
        
        let bandCount = settings.barCount
        let levels = data.levels(for: bandCount)
        let angleStep = (2.0 * .pi) / CGFloat(bandCount)
        
        let path = Path { p in
            for i in 0...bandCount {
                let idx = i % bandCount
                let level = CGFloat(levels[idx])
                let adjustedLevel = min(1.0, level * CGFloat(settings.sensitivity * 2.0))
                // Scale down expansion to prevent clipping
                let expansion = adjustedLevel * baseRadius * CGFloat(settings.waveHeight * 1.0)
                
                let radius = baseRadius + expansion
                let angle = CGFloat(i) * angleStep - .pi / 2.0
                
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                
                if i == 0 {
                    p.move(to: CGPoint(x: x, y: y))
                } else {
                    let prevIdx = (i - 1) % bandCount
                    let prevLevel = CGFloat(levels[prevIdx])
                    let prevAdjusted = min(1.0, prevLevel * CGFloat(settings.sensitivity * 2.0))
                    let prevExpansion = prevAdjusted * baseRadius * CGFloat(settings.waveHeight * 1.0)
                    
                    let prevRadius = baseRadius + prevExpansion
                    let prevAngle = CGFloat(i - 1) * angleStep - .pi / 2.0
                    
                    let prevX = center.x + cos(prevAngle) * prevRadius
                    let prevY = center.y + sin(prevAngle) * prevRadius
                    
                    let control1Angle = prevAngle + angleStep / 3.0
                    let control2Angle = angle - angleStep / 3.0
                    
                    p.addCurve(to: CGPoint(x: x, y: y),
                               control1: CGPoint(x: center.x + cos(control1Angle) * prevRadius, y: center.y + sin(control1Angle) * prevRadius),
                               control2: CGPoint(x: center.x + cos(control2Angle) * radius, y: center.y + sin(control2Angle) * radius))
                }
            }
            p.closeSubpath()
        }
        
        let color = resolveColor(palette: palette, settings: settings)
        
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 4.0 * CGFloat(settings.glowStrength * 2.0)))
            ctx.stroke(path, with: .color(color.opacity(0.8 * settings.opacity)), lineWidth: CGFloat(settings.thickness * 6.0))
        }
        
        context.drawLayer { ctx in
            ctx.stroke(path, with: .color(resolveHighlight(palette: palette, settings: settings).opacity(settings.opacity)), lineWidth: CGFloat(settings.thickness * 2.0))
        }
    }
}
