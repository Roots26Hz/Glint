import SwiftUI

protocol VisualizerRenderer {
    var settings: VisualizerSettings { get set }
    
    /// Renders the visualizer onto the provided Canvas GraphicsContext.
    /// - Parameters:
    ///   - context: The Canvas GraphicsContext.
    ///   - size: The dimensions of the canvas.
    ///   - data: The analyzed audio spectrum data.
    ///   - time: The current animation time.
    ///   - palette: The current color palette.
    func render(
        context: inout GraphicsContext,
        size: CGSize,
        data: SpectrumData,
        time: TimeInterval,
        palette: ColorPalette
    )
}
