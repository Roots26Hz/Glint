import SwiftUI

/// Compact-style volume HUD: speaker glyph in the left ear, level bar in the
/// right ear, matching the battery notification layout.
struct VolumeHUDView: View {
    var event: VolumeEvent
    var notchSize: CGSize
    @ObservedObject var music: MusicPlayerService

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(event.muted ? Color.white.opacity(0.6) : tint)
                .frame(width: 70, alignment: .center)

            Spacer()
            
            Spacer()
                .frame(width: notchSize.width)
                
            Spacer()

            levelBar
                
            Spacer()
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(event.muted ? "Muted" : "\(Int((event.level * 100).rounded())) percent")
    }

    private var levelBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.25))
            Capsule()
                .fill(event.muted ? Color.white.opacity(0.4) : tint)
                .frame(width: max(5, 70 * CGFloat(event.muted ? 0 : event.level)))
        }
        .frame(width: 70, height: 5)
        // Faster than the container's mode spring so the bar tracks keypresses.
        .animation(.easeOut(duration: 0.12), value: event)
    }

    private var tint: Color {
        music.isPlaying ? music.palette.dominant : .white
    }

    private var symbol: String {
        if event.muted || event.level == 0 { return "speaker.slash.fill" }
        switch Double(event.level) {
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}
