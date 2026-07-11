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

        // Magic constant for smooth continuous curve (bezier approximation of circle)
        let c: CGFloat = 0.5522
        let c1 = 1.0 - c

        // Top-left flare: starts at the very edge and curves inward/downward.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control1: CGPoint(x: rect.minX + top * c, y: rect.minY),
            control2: CGPoint(x: rect.minX + top, y: rect.minY + top * c1)
        )
        // Left edge down to the bottom-left rounded corner.
        p.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        p.addCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control1: CGPoint(x: rect.minX + top, y: rect.maxY - bottom * c1),
            control2: CGPoint(x: rect.minX + top + bottom * c1, y: rect.maxY)
        )
        // Bottom edge.
        p.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control1: CGPoint(x: rect.maxX - top - bottom * c1, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom * c1)
        )
        // Right edge up to the top-right flare.
        p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - top, y: rect.minY + top * c1),
            control2: CGPoint(x: rect.maxX - top * c, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }

    /// Inset area actually usable for content (excludes the top flares).
    var horizontalContentInset: CGFloat { topRadius }
}
