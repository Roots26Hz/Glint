import SwiftUI

/// The launch greeting: the lowercase **glint** wordmark from the brand
/// artwork — cursive script inked in the neon green → cyan → violet gradient
/// with a soft glow that bleeds straight into the notch's translucent glass.
/// No backing panel, no border: the glow is the only "background", and it is
/// shaped like the letters, so nothing ever reads as an image pasted on top.
///
/// The word *writes itself in*, left-to-right, as if signed by hand: a
/// soft-edged mask sweeps across so the cursive joins stay intact. Then the
/// neon glow blooms and a faint breathe holds before it auto-dismisses.
///
/// Two things are done carefully so it looks finished:
///  • The reveal mask is applied to a *padded* frame, well outside the glow's
///    blur bleed, so the mask's rectangular bounds never slice the glow into
///    a visible box.
///  • The wordmark is centered between explicit top (hardware notch) and
///    bottom (rounded corner + glow) safe areas, so the descender-heavy "g"
///    tail and the ascenders never clip — at any notch size.
struct GreetingView: View {
    var notchSize: CGSize

    /// Handwriting progress: 0 = unwritten, 1 = fully inked.
    @State private var reveal: CGFloat = 0
    /// Neon glow bloom; catches up once the word is written.
    @State private var glow = false
    @State private var breathe = false

    /// Transparent margins baked around the wordmark so the reveal mask never
    /// clips the glow (or the cursive "g" flourish) into a rectangle. Wider
    /// horizontally because the script's flourishes and its wide neon backdrop
    /// reach well past the letters on the left and right.
    private let hBleed: CGFloat = 48
    private let vBleed: CGFloat = 32
    /// Clearance under the wordmark so the "g" tail clears the rounded bottom.
    private let bottomSafe: CGFloat = 8

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Brand neon: electric green → cyan → violet (from GLINTLOGOANDARTWORK).
    private static let ink = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.96, blue: 0.65),  // green
            Color(red: 0.31, green: 0.85, blue: 1.00),  // cyan
            Color(red: 0.55, green: 0.36, blue: 1.00),  // violet
        ],
        startPoint: .leading, endPoint: .trailing
    )

    private func glyph(_ style: AnyShapeStyle) -> some View {
        Text("glint")
            .font(.custom("SnellRoundhand-Black", size: 52))
            .foregroundStyle(style)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchSize.height)   // hardware notch
            Spacer(minLength: 0)
            wordmark
            Spacer(minLength: 0)
            Color.clear.frame(height: bottomSafe)         // rounded-bottom room
        }
        .onAppear(perform: appear)
        .accessibilityElement()
        .accessibilityLabel("glint")
    }

    private var wordmark: some View {
        ZStack {
            // Wide neon backdrop: the word itself blurred out into a soft
            // colour field. It fills the space around the letters with the
            // brand neon so the greeting has a glowing background, yet it is
            // edgeless (letter-shaped, fading to nothing) — never a box.
            glyph(AnyShapeStyle(Self.ink)).blur(radius: 26).opacity(glow ? 0.5 : 0)
            // Tighter halos build the tube glow that melts into the glass.
            glyph(AnyShapeStyle(Self.ink)).blur(radius: 12).opacity(glow ? 0.7 : 0)
            glyph(AnyShapeStyle(Self.ink)).blur(radius: 4).opacity(glow ? 0.85 : 0)
            // Crisp gradient ink.
            glyph(AnyShapeStyle(Self.ink))
            // Faint white core highlight sells the glass-tube look.
            glyph(AnyShapeStyle(.white))
                .opacity(0.28)
                .blur(radius: 1.1)
                .blendMode(.screen)
        }
        .fixedSize()
        // Expand the frame past the glow's blur bleed and the cursive
        // flourishes, THEN mask — so the mask's rectangle is clipped out in
        // empty transparent space and never shows as a border.
        .padding(.horizontal, hBleed)
        .padding(.vertical, vBleed)
        .mask(alignment: .leading) {
            GeometryReader { geo in
                let feather: CGFloat = 26
                let edge = (geo.size.width + feather) * reveal
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: max(0, edge - feather))
                    LinearGradient(
                        colors: [.black, .black.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: feather)
                    Spacer(minLength: 0)
                }
            }
        }
        .scaleEffect(breathe ? 1.008 : 1.0)
    }

    private func appear() {
        if reduceMotion {
            reveal = 1
            withAnimation(.easeOut(duration: 0.4)) { glow = true }
            return
        }
        // Write the word in, let the neon bloom catch up, then breathe.
        withAnimation(.easeInOut(duration: 1.1).delay(0.35)) { reveal = 1 }
        withAnimation(.easeOut(duration: 0.9).delay(0.95)) { glow = true }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(1.7)) {
            breathe = true
        }
    }
}
