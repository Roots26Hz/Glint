import SwiftUI

/// The classic MacBook notch outline: flared top corners that blend into the
/// menu bar, rounded bottom corners. The flare and bottom radius animate so
/// the shape can morph between idle / compact / expanded sizes.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = min(topRadius, rect.height / 2)
        let bottom = min(bottomRadius, rect.height / 2)

        // Top-left flare: starts at the very edge and curves inward/downward.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        // Left edge down to the bottom-left rounded corner.
        p.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )
        // Bottom edge.
        p.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )
        // Right edge up to the top-right flare.
        p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }

    /// Inset area actually usable for content (excludes the top flares).
    var horizontalContentInset: CGFloat { topRadius }
}
