import SwiftUI

/// Notification shown temporarily when the track changes while the notch is collapsed.
struct NowPlayingNotificationView: View {
    @ObservedObject var music: MusicPlayerService
    var notchSize: CGSize

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            
            if let image = music.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .id(music.title + music.artist) // Re-animate on track change
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(music.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .id("title_" + music.title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Text(music.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .id("artist_" + music.artist)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: music.title)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        // Skip the hardware notch bounds
        .padding(.top, notchSize.height + 4)
    }
}
