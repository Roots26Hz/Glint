import SwiftUI

/// iOS-style animated equalizer bars shown in the compact live activity.
/// Bars dance while playing and settle low when paused.
struct AudioVisualizerView: View {
    var isPlaying: Bool
    var color: Color = .white
    var barCount: Int = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: barHeight(index: index, time: t))
                }
            }
        }
        .frame(height: 16, alignment: .center)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 3 }
        // Layered sines at co-prime frequencies read as organically random.
        let phase = Double(index) * 1.9
        let wave = sin(time * 5.3 + phase) * 0.5
            + sin(time * 8.9 + phase * 1.3) * 0.3
            + sin(time * 2.2 + phase * 0.7) * 0.2
        return 3 + CGFloat((wave + 1) / 2) * 13
    }
}
