import SwiftUI

struct LiquidFlowRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let color = resolveColor(palette: palette, settings: settings)
        
        let pointCount = settings.barCount
        let levels = data.levels(for: pointCount)
        let step = size.width / CGFloat(pointCount - 1)
        
        let path = Path { p in
            p.move(to: CGPoint(x: 0, y: size.height))
            
            for i in 0..<pointCount {
                let level = CGFloat(levels[i])
                let adjustedLevel = min(1.0, level * CGFloat(settings.sensitivity * 2.0))
                let height = adjustedLevel * size.height * CGFloat(settings.waveHeight * 2.0)
                let y = size.height - height
                let x = CGFloat(i) * step
                
                if i == 0 {
                    p.addLine(to: CGPoint(x: x, y: y))
                } else {
                    // Smooth cubic bezier
                    let prevX = CGFloat(i - 1) * step
                    let prevLevel = CGFloat(data.levels[i-1])
                    let prevAdjusted = min(1.0, prevLevel * CGFloat(settings.sensitivity * 2.0))
                    let prevY = size.height - (prevAdjusted * size.height * CGFloat(settings.waveHeight * 2.0))
                    
                    let controlX1 = prevX + (step / 2)
                    let controlX2 = x - (step / 2)
                    
                    p.addCurve(to: CGPoint(x: x, y: y),
                               control1: CGPoint(x: controlX1, y: prevY),
                               control2: CGPoint(x: controlX2, y: y))
                }
            }
            
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
        
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 6.0 * CGFloat(settings.glowStrength * 2.0)))
            ctx.fill(path, with: .color(color.opacity(0.5 * settings.opacity)))
        }
        
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 2.0 * CGFloat(settings.glowStrength * 2.0)))
            ctx.fill(path, with: .color(color.opacity(0.8 * settings.opacity)))
        }
        
        // Crisp edge
        context.stroke(path, with: .color(resolveHighlight(palette: palette, settings: settings).opacity(settings.opacity)), lineWidth: CGFloat(settings.thickness * 4.0))
    }
}
