import SwiftUI

/// Track-change card, shown briefly when the song changes while the notch is
/// collapsed: a drop-down hanging below the notch with the artwork and track
/// info centered — the artwork-palette wash from the container tints the
/// glass to match the cover.
struct NowPlayingNotificationView: View {
    @ObservedObject var music: MusicPlayerService
    var notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            // Leave the hardware notch region empty.
            Spacer()
                .frame(height: notchSize.height)

            HStack(spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 2) {
                    Text(music.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .id("title_" + music.title)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    Text(music.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .id("artist_" + music.artist)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: music.title)
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement()
        .accessibilityLabel("Now playing")
        .accessibilityValue("\(music.title) by \(music.artist)")
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = music.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .id(music.title + music.artist) // Re-animate on track change
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }
}
