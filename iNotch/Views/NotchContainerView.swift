import SwiftUI

/// Top-level SwiftUI content of the notch panel. Renders the notch shape at
/// the size demanded by the current mode and swaps the inner content,
/// morphing between states with a spring.
struct NotchContainerView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var isExpanded: Bool { viewModel.mode == .expandedMusic }

    private var topRadius: CGFloat {
        switch viewModel.mode {
        case .idle: return 6
        case .compactMusic, .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected:
            return 9
        case .expandedMusic: return 14
        }
    }

    private var bottomRadius: CGFloat {
        switch viewModel.mode {
        case .idle: return 11
        case .compactMusic, .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected:
            return 14
        case .expandedMusic: return 26
        }
    }

    var body: some View {
        let size = viewModel.contentSize
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)

        ZStack(alignment: .top) {
            background(in: shape)
                .overlay {
                    if viewModel.mode == .expandedMusic {
                        ArtworkWash(music: viewModel.music, height: size.height)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .top) {
                    content
                        .padding(.horizontal, topRadius)
                }
                .overlay(alignment: .top) {
                    // The hardware notch physically blacks out this rect, so
                    // painting it changes nothing to the eye — but screenshots
                    // and recordings capture the framebuffer *behind* the
                    // bezel, and without this they show glass where a viewer
                    // sees black.
                    NotchShape(topRadius: 6, bottomRadius: 11)
                        .fill(.black)
                        .frame(
                            width: viewModel.notchSize.width + 12,
                            height: viewModel.notchSize.height
                        )
                        .allowsHitTesting(false)
                }
                .clipShape(shape)
                .shadow(
                    color: .black.opacity(viewModel.mode == .idle ? 0 : 0.55),
                    radius: 10, y: 3
                )
                .frame(width: size.width + topRadius * 2, height: size.height)
                .contentShape(shape)
                .onHover { viewModel.hoverChanged($0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Mode changes are animated solely by setMode's withAnimation, which
        // picks a curve per transition; a second .animation here would
        // override those choices.
    }

    /// Idle mimics the hardware bezel exactly (pure black); every active mode
    /// gets a Liquid Glass body that blurs and color-adapts to whatever is
    /// behind the panel, darkened enough to keep white content legible.
    /// Both layers are always present so idle ↔ active is a smooth dissolve
    /// of the black cover rather than a view replacement.
    private func background(in shape: NotchShape) -> some View {
        Color.clear
            .glassEffect(.regular.tint(.black.opacity(0.5)), in: shape)
            .overlay {
                shape.fill(.black)
                    .opacity(viewModel.mode == .idle ? 1 : 0)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.mode {
        case .idle:
            Color.clear
                .frame(width: viewModel.notchSize.width, height: viewModel.notchSize.height)

        case .compactMusic:
            CompactMusicView(
                music: viewModel.music,
                notchSize: viewModel.notchSize
            )
            .transition(.blurReplace)

        case .expandedMusic:
            ExpandedMusicView(
                music: viewModel.music,
                notchHeight: viewModel.notchSize.height
            )
            .transition(.blurReplace)

        case .batteryAlert(let event):
            BatteryNotificationView(
                event: event,
                notchSize: viewModel.notchSize
            )
            .transition(.blurReplace)

        case .volumeHUD(let event):
            VolumeHUDView(
                event: event,
                notchSize: viewModel.notchSize,
                music: viewModel.music
            )
            .transition(.blurReplace)

        case .brightnessHUD(let event):
            BrightnessHUDView(
                event: event,
                notchSize: viewModel.notchSize,
                music: viewModel.music
            )
            .transition(.blurReplace)

        case .bluetoothConnected(let event):
            BluetoothNotificationView(
                event: event,
                notchSize: viewModel.notchSize
            )
            .transition(.blurReplace)
        }
    }
}

/// Subtle artwork-colored glow behind the expanded player. A separate view so
/// it observes MusicPlayerService and re-renders when the accent changes.
private struct ArtworkWash: View {
    @ObservedObject var music: MusicPlayerService
    var height: CGFloat

    var body: some View {
        RadialGradient(
            colors: [music.artworkColor.opacity(0.22), .clear],
            center: .top,
            startRadius: 0,
            endRadius: height
        )
        .allowsHitTesting(false)
    }
}
