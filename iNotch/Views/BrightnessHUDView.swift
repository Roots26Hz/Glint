import SwiftUI

/// Compact-style brightness HUD: sun glyph in the left ear, level bar in the
/// right ear, matching the volume HUD layout.
struct BrightnessHUDView: View {
    var event: BrightnessEvent
    var notchSize: CGSize
    @ObservedObject var music: MusicPlayerService

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: event.level < 0.34 ? "sun.min.fill" : "sun.max.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, alignment: .leading)
                .padding(.leading, 15)

            Spacer(minLength: notchSize.width - 40)

            levelBar
                .padding(.trailing, 15)
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int((event.level * 100).rounded())) percent")
    }

    private var levelBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.25))
            Capsule()
                .fill(tint)
                .frame(width: max(5, 70 * CGFloat(event.level)))
        }
        .frame(width: 70, height: 5)
        // Faster than the container's mode spring so the bar tracks keypresses.
        .animation(.easeOut(duration: 0.12), value: event)
    }

    private var tint: Color {
        music.isPlaying ? music.artworkColor : .white
    }
}
