import SwiftUI

struct PremiumVisualizerView: View {
    var isPlaying: Bool
    var palette: ColorPalette
    @ObservedObject var analyzer: AudioSpectrumAnalyzer
    
    // For live preview, we want to allow passing in settings.
    var customSettings: VisualizerSettings? = nil
    
    @ObservedObject private var manager = VisualizerSettingsManager.shared
    
    private var activeSettings: VisualizerSettings {
        customSettings ?? manager.settings
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(activeSettings.fpsLimit), paused: !isPlaying && !activeSettings.idleAnimation)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let data = analyzer.isCapturing ? analyzer.data : simulatedData(time: t)
                 
                var renderer = renderer(for: activeSettings.style, settings: activeSettings)
                
                // Handle mirroring
                if activeSettings.mirrorLeftRight {
                    let halfWidth = size.width / 2
                    
                    // Left side (normal)
                    var leftContext = context
                    leftContext.clip(to: Path(CGRect(x: 0, y: 0, width: halfWidth, height: size.height)))
                    renderer.render(context: &leftContext, size: size, data: data, time: t, palette: palette)
                    
                    // Right side (mirrored)
                    var rightContext = context
                    rightContext.clip(to: Path(CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)))
                    rightContext.translateBy(x: size.width, y: 0)
                    rightContext.scaleBy(x: -1, y: 1)
                    renderer.render(context: &rightContext, size: size, data: data, time: t, palette: palette)
                } else {
                    renderer.render(context: &context, size: size, data: data, time: t, palette: palette)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: activeSettings.style)
        }
        .frame(height: 24, alignment: .center)
    }
    
    private func renderer(for style: VisualizerStyle, settings: VisualizerSettings) -> any VisualizerRenderer {
        switch style {
        case .appleClassic: return AppleClassicRenderer(settings: settings)
        case .centerEqualizer: return CenterEqualizerRenderer(settings: settings)
        case .liquidFlow: return LiquidFlowRenderer(settings: settings)
        case .glassPulse: return GlassPulseRenderer(settings: settings)
        case .spectrum: return SpectrumRenderer(settings: settings)
        case .energyRing: return EnergyRingRenderer(settings: settings)
        case .adaptive: return AdaptiveRenderer(settings: settings)
        }
    }
    
    private func simulatedData(time: Double) -> SpectrumData {
        guard isPlaying || activeSettings.idleAnimation else { return .empty }
        var levels = [Float](repeating: 0, count: AudioSpectrumAnalyzer.bandCount)
        let impulse = Float(sin(time * 2.0) > 0.9 ? 1.0 : 0.0)
        
        for i in 0..<levels.count {
            let phase = Double(i) * 0.5
            let speed = 1.0 + Double(i) * 0.1
            levels[i] = Float(max(0, sin(time * speed + phase) * 0.5 + 0.5))
        }
        return SpectrumData(levels: levels, bassEnergy: levels[0], midEnergy: levels[8], trebleEnergy: levels[15], beatImpulse: impulse)
    }
}
