import SwiftUI

/// Compact live activity: album art in the left "ear", soundwave bars in
/// the right ear, with the hardware notch spanning the black gap between.
struct CompactMusicView: View {
    @ObservedObject var music: MusicPlayerService
    var notchSize: CGSize



    var body: some View {
        HStack(spacing: 0) {
            artwork
                .frame(width: 65)
            Spacer(minLength: notchSize.width)
            soundwave
                .frame(width: 65)
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder
    private var soundwave: some View {
        PremiumVisualizerView(isPlaying: music.isPlaying, palette: music.palette, analyzer: music.spectrumAnalyzer)
            .frame(width: 44)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = music.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }
}
