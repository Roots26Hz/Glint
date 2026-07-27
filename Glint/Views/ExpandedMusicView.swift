import SwiftUI

/// Full player revealed on hover: artwork, track info, seekable progress
/// bar, and Liquid Glass transport controls.
struct ExpandedMusicView: View {
    @ObservedObject var music: MusicPlayerService
    var notchHeight: CGFloat

    @Namespace private var glassSpace
    // Tap counters so the skip glyphs bounce on every press.
    @State private var skipBackTaps = 0
    @State private var skipForwardTaps = 0

    // Staggered animation states
    @State private var artworkVisible = false
    @State private var textVisible = false
    @State private var controlsVisible = false

    private var hasTrack: Bool { !music.title.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Leave the hardware notch region empty.
            Spacer()
                .frame(height: notchHeight - 4)

            GlassEffectContainer(spacing: 18) {
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 14) {
                        artwork
                            .scaleEffect(artworkVisible ? 1 : 0.9)
                            .opacity(artworkVisible ? 1 : 0)

                        VStack(alignment: .leading, spacing: 7) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(music.title.isEmpty ? "Not Playing" : music.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(music.palette.highlight)
                                    .lineLimit(1)
                                Text(music.artist)
                                    .font(.system(size: 11))
                                    .foregroundStyle(music.palette.secondary)
                                    .lineLimit(1)
                            }
                            .id(music.title)
                            .transition(.blurReplace)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: music.title)
                            .opacity(textVisible ? 1 : 0)
                            .offset(y: textVisible ? 0 : 5)

                            if hasTrack {
                                ProgressBar(music: music)
                                    .opacity(textVisible ? 1 : 0)
                            }

                            controls
                                .frame(maxWidth: .infinity, alignment: .center)
                                .opacity(controlsVisible ? 1 : 0)
                                .offset(y: controlsVisible ? 0 : 5)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 0)
                }
            }
        }
        .onAppear {
            triggerStaggeredEntry()
        }
    }

    private func triggerStaggeredEntry() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
            artworkVisible = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15)) {
            textVisible = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.25)) {
            controlsVisible = true
        }
    }

    private var artwork: some View {
        ZStack {
            if let image = music.artwork {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .id(music.artworkKey)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                .id(music.artworkKey)
                .transition(.opacity)
            }
            
            if music.isArtworkLoading {
                ProgressView()
                    .controlSize(.regular)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffectID("artwork", in: glassSpace)
        .shadow(color: music.isPlaying ? music.palette.glow.opacity(0.6) : .black.opacity(0.4), radius: 8, y: 3)
        .animation(.easeInOut(duration: 0.4), value: music.artworkKey)
        .animation(.easeInOut(duration: 0.3), value: music.isArtworkLoading)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: music.isPlaying)
    }

    private var controls: some View {
        HStack(spacing: 2) {
            // Skip/shuffle/repeat are meaningless without a track; play still
            // works (it launches Music and resumes the last playback context).
            if hasTrack {
                toggleButton(
                    "shuffle", label: "Shuffle", isOn: music.shuffleEnabled,
                    bounce: music.shuffleEnabled
                ) {
                    music.toggleShuffle()
                }
                transportButton("backward.fill", label: "Previous Track", size: 13, bounce: skipBackTaps) {
                    skipBackTaps += 1
                    music.previousTrack()
                }
            }
            playPauseButton
            if hasTrack {
                transportButton("forward.fill", label: "Next Track", size: 13, bounce: skipForwardTaps) {
                    skipForwardTaps += 1
                    music.nextTrack()
                }
                toggleButton(
                    music.repeatMode == .one ? "repeat.1" : "repeat",
                    label: "Repeat", isOn: music.repeatMode != .off,
                    bounce: music.repeatMode
                ) {
                    music.cycleRepeat()
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasTrack)
    }

    private var playPauseButton: some View {
        Button {
            music.playPause()
        } label: {
            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(music.palette.highlight)
                // Morph play ⇄ pause layer-by-layer instead of swapping.
                .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: music.isPlaying)
                .frame(width: 40, height: 40)
                .glassEffect(
                    .regular.tint(music.palette.dominant.opacity(0.35)).interactive(),
                    in: Circle()
                )
                // A stable ID — keying on the symbol would change the ID on
                // every toggle and defeat the glass morph.
                .glassEffectID("playpause", in: glassSpace)
                .padding(2)
                .contentShape(Circle())
        }
        .buttonStyle(HoverGlowingButtonStyle(palette: music.palette))
        .accessibilityLabel(music.isPlaying ? "Pause" : "Play")
    }

    private func transportButton(
        _ symbol: String, label: String, size: CGFloat, bounce: some Equatable,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(music.palette.highlight)
                .symbolEffect(.bounce, options: .speed(1.4), value: bounce)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.interactive(), in: Circle())
                .glassEffectID(symbol, in: glassSpace)
                // Pad the hit region out beyond the visible circle.
                .padding(6)
                .contentShape(Circle())
        }
        .buttonStyle(HoverGlowingButtonStyle(palette: music.palette))
        .accessibilityLabel(label)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }

    /// Shuffle / repeat: smaller circles whose glyph lights up in the artwork
    /// color while active.
    private func toggleButton(
        _ symbol: String, label: String, isOn: Bool, bounce: some Equatable,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isOn ? music.palette.dominant : music.palette.secondary)
                .symbolEffect(.bounce, options: .speed(1.4), value: bounce)
                .contentTransition(.symbolEffect(.replace))
                .animation(.smooth(duration: 0.25), value: isOn)
                .frame(width: 24, height: 24)
                .glassEffect(.regular.interactive(), in: Circle())
                .glassEffectID(label, in: glassSpace)
                .padding(6)
                .contentShape(Circle())
        }
        .buttonStyle(HoverGlowingButtonStyle(palette: music.palette))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }
}

private struct HoverGlowingButtonStyle: ButtonStyle {
    var palette: ColorPalette
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : (isHovering ? 1.08 : 1))
            .brightness(configuration.isPressed ? 0.2 : (isHovering ? 0.15 : 0))
            .shadow(color: isHovering ? palette.glow.opacity(0.8) : .clear, radius: isHovering ? 8 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// Seekable progress bar with elapsed / remaining timestamps.
private struct ProgressBar: View {
    @ObservedObject var music: MusicPlayerService
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.animation) { timeline in
            VStack(spacing: 3) {
                GeometryReader { geo in
                    let fraction = currentFraction(at: timeline.date)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.25))
                        Capsule()
                            .fill(
                                LinearGradient(colors: [music.palette.secondary, music.palette.dominant], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(4, geo.size.width * fraction))
                            .shadow(color: music.palette.glow.opacity(0.7), radius: 3)
                    }
                    .contentShape(Rectangle().inset(by: -6))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        // Elastic rubber-banding at the edges
                                        if x < 0 {
                                            dragFraction = min(max((x * 0.2) / geo.size.width, 0), 1)
                                        } else if x > geo.size.width {
                                            dragFraction = min(max(1 + ((x - geo.size.width) * 0.2) / geo.size.width, 0), 1)
                                        } else {
                                            dragFraction = min(max(x / geo.size.width, 0), 1)
                                        }
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
                    Text(timeString(currentFraction(at: timeline.date) * max(music.duration, 1)))
                    Spacer()
                    Text("-" + timeString(max(music.duration - currentFraction(at: timeline.date) * music.duration, 0)))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                // ≥0.7 keeps 4.5:1 over the lightest glass state.
                .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement()
            .accessibilityLabel("Playback position")
            .accessibilityValue(
                "\(timeString(currentFraction(at: timeline.date) * max(music.duration, 1))) of \(timeString(music.duration))"
            )
            .accessibilityAdjustableAction { direction in
                let delta: Double = direction == .increment ? 5 : -5
                music.seek(to: min(max(music.position + delta, 0), music.duration))
            }
        }
    }

    private func currentFraction(at date: Date) -> Double {
        if let dragFraction { return dragFraction }
        guard music.duration > 0 else { return 0 }
        let timeSinceUpdate = music.isPlaying ? date.timeIntervalSince(music.lastPositionUpdate) : 0
        let interpolatedPosition = music.position + timeSinceUpdate
        return min(interpolatedPosition / music.duration, 1)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
