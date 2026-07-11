import SwiftUI

struct PremiumVisualizerView: View {
    var isPlaying: Bool
    var palette: ColorPalette
    
    @StateObject private var analyzer = AudioSpectrumAnalyzer()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let data = analyzer.isCapturing ? analyzer.data : simulatedData(time: t)
                
                let bars = AudioSpectrumAnalyzer.bandCount
                let spacing: CGFloat = 2
                let totalSpacing = spacing * CGFloat(bars - 1)
                let barWidth = (size.width - totalSpacing) / CGFloat(bars)
                
                for i in 0..<bars {
                    let level = CGFloat(data.levels[i])
                    // Ensure a minimum height of 2 pixels so the bar is always visible
                    let barHeight = max(2, level * size.height)
                    
                    let x = CGFloat(i) * (barWidth + spacing)
                    // Anchor at the bottom
                    let y = size.height - barHeight
                    
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    
                    context.fill(path, with: .color(palette.dominant))
                }
            }
        }
        .frame(height: 24, alignment: .center)
        .onAppear { syncCapture() }
        .onDisappear { analyzer.stop() }
        .onChange(of: isPlaying) { syncCapture() }
    }
    
    private func simulatedData(time: Double) -> SpectrumData {
        guard isPlaying else { return .empty }
        var levels = [Float](repeating: 0, count: AudioSpectrumAnalyzer.bandCount)
        for i in 0..<levels.count {
            let phase = Double(i) * 0.5
            let speed = 1.0 + Double(i) * 0.1
            levels[i] = Float(max(0, sin(time * speed + phase) * 0.5 + 0.5))
        }
        return SpectrumData(levels: levels, bassEnergy: levels[0], midEnergy: levels[8], trebleEnergy: levels[15], beatImpulse: 0)
    }
    
    private func syncCapture() {
        if isPlaying {
            analyzer.start()
        } else {
            analyzer.stop()
        }
    }
}
