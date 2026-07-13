import SwiftUI

/// The launch greeting: "Glint." in a real cursive typeface (SnellRoundhand
/// Black — uniform letterforms), inked with the Apple-"hello" gradient and
/// glow, revealed left-to-right like it's being written. The card springs
/// open via the shared mode animation.
struct GreetingView: View {
    var notchSize: CGSize

    @State private var progress: CGFloat = 0

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// hello ink: blue at the start, warming to orange at the end.
    private static let ink = LinearGradient(
        stops: [
            .init(color: Color(red: 0.32, green: 0.62, blue: 1.00), location: 0.05),
            .init(color: Color(red: 0.48, green: 0.44, blue: 1.00), location: 0.28),
            .init(color: Color(red: 0.66, green: 0.38, blue: 0.96), location: 0.50),
            .init(color: Color(red: 0.88, green: 0.40, blue: 0.80), location: 0.70),
            .init(color: Color(red: 1.00, green: 0.58, blue: 0.36), location: 0.88),
        ],
        startPoint: .leading, endPoint: .trailing
    )

    private var word: some View {
        Text("Glint.")
            .font(.custom("SnellRoundhand-Black", size: 46))
            .foregroundStyle(Self.ink)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Leave the hardware notch region empty.
            Spacer()
                .frame(height: notchSize.height)

            ZStack {
                // Halo passes make the script glow on the dark glass.
                word.blur(radius: 13).opacity(0.75)
                word.blur(radius: 4).opacity(0.85)
                word
            }
            .frame(width: 280, height: 72)
            .mask(
                // Soft-edged wipe that follows the writing direction; the
                // overshoot in write() carries the blurred edge fully past
                // the period.
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: geo.size.width * progress)
                        .blur(radius: 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .onAppear(perform: write)
        .accessibilityElement()
        .accessibilityLabel("Glint")
    }

    private func write() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.5)) { progress = 1.3 }
            return
        }
        // Start once the card has sprung open, then sweep at writing pace.
        withAnimation(.easeInOut(duration: 1.7).delay(0.4)) {
            progress = 1.3
        }
    }
}
