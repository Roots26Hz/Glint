import SwiftUI

/// Full player revealed on hover: artwork, track info, seekable progress
/// bar, and Liquid Glass transport controls.
struct ExpandedMusicView: View {
    @ObservedObject var music: MusicPlayerService
    var notchHeight: CGFloat

    @Namespace private var glassSpace

    private var hasTrack: Bool { !music.title.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Leave the hardware notch region empty.
            Spacer()
                .frame(height: notchHeight - 4)

            GlassEffectContainer(spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    artwork

                    VStack(alignment: .leading, spacing: 7) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(music.title.isEmpty ? "Not Playing" : music.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(music.artist)
                                .font(.system(size: 11))
                                // ≥0.75 keeps 4.5:1 over the lightest glass state.
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }

                        if hasTrack {
                            ProgressBar(music: music)
                        }

                        controls
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 14)
            }
        }
    }

    private var artwork: some View {
        Group {
            if let image = music.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(white: 0.25), Color(white: 0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffectID("artwork", in: glassSpace)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }

    private var controls: some View {
        HStack(spacing: 2) {
            // Skip buttons are meaningless without a track; play still works
            // (it launches Music and resumes the last playback context).
            if hasTrack {
                transportButton("backward.fill", label: "Previous Track", size: 13) {
                    music.previousTrack()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
            transportButton(
                music.isPlaying ? "pause.fill" : "play.fill",
                label: music.isPlaying ? "Pause" : "Play",
                size: 17, prominent: true
            ) {
                music.playPause()
            }
            if hasTrack {
                transportButton("forward.fill", label: "Next Track", size: 13) {
                    music.nextTrack()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasTrack)
    }

    private func transportButton(
        _ symbol: String, label: String, size: CGFloat, prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: prominent ? 40 : 32, height: prominent ? 40 : 32)
                .glassEffect(
                    prominent
                        ? .regular.tint(music.artworkColor.opacity(0.35)).interactive()
                        : .regular.interactive(),
                    in: Circle()
                )
                // A stable ID for play/pause — keying on the symbol would
                // change the ID on every toggle and defeat the glass morph.
                .glassEffectID(prominent ? "playpause" : symbol, in: glassSpace)
                // Pad the hit region out to 44×44 beyond the visible circle.
                .padding(prominent ? 2 : 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Seekable progress bar with elapsed / remaining timestamps.
private struct ProgressBar: View {
    @ObservedObject var music: MusicPlayerService
    @State private var dragFraction: Double?

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let fraction = currentFraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                    Capsule()
                        .fill(music.artworkColor)
                        .frame(width: max(4, geo.size.width * fraction))
                }
                .contentShape(Rectangle().inset(by: -6))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = min(max(value.location.x / geo.size.width, 0), 1)
                        }
                        .onEnded { value in
                            let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                            music.seek(to: fraction * music.duration)
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 5)

            HStack {
                Text(timeString(currentFraction * max(music.duration, 1)))
                Spacer()
                Text("-" + timeString(max(music.duration - currentFraction * music.duration, 0)))
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            // ≥0.7 keeps 4.5:1 over the lightest glass state.
            .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(
            "\(timeString(currentFraction * max(music.duration, 1))) of \(timeString(music.duration))"
        )
        .accessibilityAdjustableAction { direction in
            let delta: Double = direction == .increment ? 5 : -5
            music.seek(to: min(max(music.position + delta, 0), music.duration))
        }
    }

    private var currentFraction: Double {
        if let dragFraction { return dragFraction }
        guard music.duration > 0 else { return 0 }
        return min(music.position / music.duration, 1)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
