import SwiftUI

/// Audio-reactive equalizer for the compact live activity: five bars driven
/// by the real frequency content of Music's output (bass on the left, treble
/// on the right), styled to match AudioVisualizerView. When capture is
/// unavailable — permission denied, Music not tappable — it falls back to the
/// procedural visualizer so the ear is never empty.
struct AudioEqualizerView: View {
    var isPlaying: Bool
    var color: Color = .white

    @StateObject private var analyzer = AudioSpectrumAnalyzer()

    private static let barWidth: CGFloat = 2.5
    private static let barSpacing: CGFloat = 2
    private static let maxHeight: CGFloat = 16

    var body: some View {
        Group {
            if analyzer.isCapturing {
                bars
            } else {
                AudioVisualizerView(isPlaying: isPlaying, color: color)
            }
        }
        .onAppear { syncCapture() }
        .onDisappear { analyzer.stop() }
        .onChange(of: isPlaying) { syncCapture() }
    }

    /// Capture runs only while this view is on screen and music is playing,
    /// so the system's recording indicator clears as soon as playback stops.
    private func syncCapture() {
        if isPlaying {
            analyzer.start()
        } else {
            analyzer.stop()
        }
    }

    private var bars: some View {
        HStack(spacing: Self.barSpacing) {
            ForEach(0..<AudioSpectrumAnalyzer.bandCount, id: \.self) { band in
                Capsule()
                    .fill(gradient)
                    .frame(width: Self.barWidth, height: height(band: band))
            }
        }
        .shadow(color: color.opacity(0.4), radius: 3)
        // Levels arrive at ~30 Hz; a short linear blend keeps motion fluid
        // between updates without smearing the beat.
        .animation(.linear(duration: 0.08), value: analyzer.levels)
        .frame(height: Self.maxHeight, alignment: .center)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.55)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func height(band: Int) -> CGFloat {
        let restHeight = Self.barWidth // silent bands read as round dots
        let level = CGFloat(analyzer.levels[band])
        return restHeight + level * (Self.maxHeight - restHeight)
    }
}
