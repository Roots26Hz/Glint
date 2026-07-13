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
        case .compactMusic, .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected,
             .nowPlayingNotification, .greeting:
            return 12
        case .expandedMusic: return 20
        }
    }

    private var bottomRadius: CGFloat {
        switch viewModel.mode {
        case .idle: return 11
        case .compactMusic, .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected:
            return 20
        case .nowPlayingNotification, .greeting: return 26
        case .expandedMusic: return 34
        }
    }

    var body: some View {
        let size = viewModel.contentSize
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)

        ZStack(alignment: .top) {
            background(in: shape)
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
                .globalHover { viewModel.hoverChanged($0) }
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
            .glassEffect(.regular.tint(.black.opacity(0.35)), in: shape)
            .overlay {
                if viewModel.mode == .expandedMusic || viewModel.mode == .nowPlayingNotification {
                    ZStack {
                        viewModel.music.palette.background
                        if let image = viewModel.music.artwork {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 50)
                                .opacity(0.6)
                                .modifier(SlowRotationModifier())
                        }
                    }
                    .transition(.opacity)
                }
            }
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

        case .nowPlayingNotification:
            NowPlayingNotificationView(
                music: viewModel.music,
                notchSize: viewModel.notchSize
            )
            .transition(.blurReplace)

        case .batteryAlert(let event):
            BatteryNotificationView(
                event: event,
                notchSize: viewModel.notchSize
            )
            .transition(transientTransition)

        case .volumeHUD(let event):
            VolumeHUDView(
                event: event,
                notchSize: viewModel.notchSize,
                music: viewModel.music
            )
            .transition(transientTransition)

        case .brightnessHUD(let event):
            BrightnessHUDView(
                event: event,
                notchSize: viewModel.notchSize,
                music: viewModel.music
            )
            .transition(transientTransition)

        case .bluetoothConnected(let event):
            BluetoothNotificationView(
                event: event,
                notchSize: viewModel.notchSize
            )
            .transition(transientTransition)

        case .greeting:
            GreetingView(notchSize: viewModel.notchSize)
                .transition(.blurReplace)
        }
    }
    
    private var transientTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
            removal: .move(edge: .top).combined(with: .opacity).animation(.easeIn(duration: 0.2))
        )
    }
}

struct SlowRotationModifier: ViewModifier {
    @State private var rotation: Double = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct GlobalHoverView: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onHover = onHover
    }

    class TrackingView: NSView {
        var onHover: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect
            ]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            self.trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            onHover?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHover?(false)
        }
    }
}

extension View {
    func globalHover(perform action: @escaping (Bool) -> Void) -> some View {
        self.background(GlobalHoverView(onHover: action))
    }
}
