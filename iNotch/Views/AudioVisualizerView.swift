import SwiftUI

/// Apple Music-style animated equalizer bars shown in the compact live
/// activity. Bars dance while playing — taller near the center, gently
/// glowing in the artwork color — and melt into a row of dots when paused.
struct AudioVisualizerView: View {
    var isPlaying: Bool
    var color: Color = .white
    var barCount: Int = 5

    private static let barWidth: CGFloat = 3
    private static let maxHeight: CGFloat = 16
    /// Dome profile: center bars swing higher than the outer ones, like the
    /// Apple Music icon, instead of uniform noise.
    private static let profile: [CGFloat] = [0.6, 0.85, 1.0, 0.85, 0.65]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40.0, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(gradient)
                        .frame(width: Self.barWidth, height: barHeight(index: index, time: t))
                }
            }
            .shadow(color: color.opacity(isPlaying ? 0.4 : 0), radius: 3)
            // The timeline freezes on pause; this eases the final change so
            // the bars settle into dots instead of snapping.
            .animation(.smooth(duration: 0.35), value: isPlaying)
        }
        .frame(height: Self.maxHeight, alignment: .center)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.55)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let restHeight = Self.barWidth // paused bars read as round dots
        guard isPlaying else { return restHeight }
        // Layered sines at co-prime frequencies read as organically random.
        let phase = Double(index) * 1.9
        let wave = sin(time * 5.3 + phase) * 0.5
            + sin(time * 8.9 + phase * 1.3) * 0.3
            + sin(time * 2.2 + phase * 0.7) * 0.2
        let amplitude = Self.profile[index % Self.profile.count]
        return restHeight + CGFloat((wave + 1) / 2) * (Self.maxHeight - restHeight) * amplitude
    }
}
