import SwiftUI

/// Compact live activity: album art in the left "ear", visualizer bars in
/// the right ear, with the hardware notch spanning the black gap between.
struct CompactMusicView: View {
    @ObservedObject var music: MusicPlayerService
    var notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            artwork
                .padding(.leading, 13)
            Spacer(minLength: notchSize.width)
            AudioVisualizerView(isPlaying: music.isPlaying, color: music.artworkColor)
                .padding(.trailing, 15)
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = music.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 19, height: 19)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 19, height: 19)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }
}
