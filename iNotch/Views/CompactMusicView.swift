import SwiftUI

/// Compact live activity: album art in the left "ear", soundwave bars in
/// the right ear, with the hardware notch spanning the black gap between.
struct CompactMusicView: View {
    @ObservedObject var music: MusicPlayerService
    var notchSize: CGSize

    @AppStorage(Preferences.musicWaveStyleKey)
    private var waveStyle = Preferences.musicWaveStyleEqualizer

    var body: some View {
        HStack(spacing: 0) {
            artwork
                .padding(.leading, 13)
            Spacer(minLength: notchSize.width)
            soundwave
                .padding(.trailing, 15)
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder
    private var soundwave: some View {
        if waveStyle == Preferences.musicWaveStyleEqualizer {
            AudioEqualizerView(isPlaying: music.isPlaying, color: music.artworkColor)
        } else {
            AudioVisualizerView(isPlaying: music.isPlaying, color: music.artworkColor)
        }
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
