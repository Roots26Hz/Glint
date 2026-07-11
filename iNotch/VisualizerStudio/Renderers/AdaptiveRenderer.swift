import SwiftUI

struct AdaptiveRenderer: VisualizerRenderer {
    var settings: VisualizerSettings
    
    func render(context: inout GraphicsContext, size: CGSize, data: SpectrumData, time: TimeInterval, palette: ColorPalette) {
        let totalEnergy = data.bassEnergy + data.midEnergy + data.trebleEnergy
        
        // Very simple adaptive logic:
        // High bass -> Glass Pulse
        // High energy -> Liquid
        // Low energy -> Classic
        
        if data.bassEnergy > 0.6 {
            let renderer = GlassPulseRenderer(settings: settings)
            renderer.render(context: &context, size: size, data: data, time: time, palette: palette)
        } else if totalEnergy > 1.2 {
            let renderer = LiquidFlowRenderer(settings: settings)
            renderer.render(context: &context, size: size, data: data, time: time, palette: palette)
        } else {
            let renderer = AppleClassicRenderer(settings: settings)
            renderer.render(context: &context, size: size, data: data, time: time, palette: palette)
        }
    }
}
