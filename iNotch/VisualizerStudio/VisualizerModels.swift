import SwiftUI

enum VisualizerStyle: String, CaseIterable, Identifiable, Codable {
    case appleClassic = "Apple Classic"
    case centerEqualizer = "Center Equalizer"
    case liquidFlow = "Liquid Flow"
    case glassPulse = "Glass Pulse"
    case spectrum = "Spectrum"
    case energyRing = "Energy Ring"
    case adaptive = "Adaptive"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .appleClassic: return "Elegant vertical bars with soft glow."
        case .centerEqualizer: return "Original center-aligned waveform."
        case .liquidFlow: return "Smooth flowing organic ribbon."
        case .glassPulse: return "Translucent pulsing layers inside glass."
        case .spectrum: return "Modern adaptive frequency bars."
        case .energyRing: return "Circular expanding waveform."
        case .adaptive: return "Automatically switches based on audio energy."
        }
    }
}

struct VisualizerSettings: Codable, Equatable {
    var style: VisualizerStyle = .appleClassic
    
    // Core parameters (0.0 to 1.0)
    var barCount: Int = 16
    var animationSpeed: Double = 0.5
    var waveHeight: Double = 0.5
    var glowStrength: Double = 0.5
    var opacity: Double = 0.8
    var thickness: Double = 0.5
    var sensitivity: Double = 0.5
    var bassBoost: Double = 0.5
    var blurAmount: Double = 0.5
    var cornerRadius: Double = 0.5
    var smoothness: Double = 0.5
    
    // Advanced options
    var layerCount: Int = 3
    var fpsLimit: Int = 120
    var mirrorLeftRight: Bool = false
    var centerOutAnimation: Bool = false
    var randomMotionStrength: Double = 0.5
    var idleAnimation: Bool = true
    var beatPulseStrength: Double = 0.5
    var bloomIntensity: Double = 0.5
    var reflectionIntensity: Double = 0.5
    var adaptiveBrightness: Bool = true
    
    // Default settings
    static let `default` = VisualizerSettings()
}

// UserDefaults storage extension
extension VisualizerSettings {
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "VisualizerSettings")
        }
    }
    
    static func load() -> VisualizerSettings {
        if let data = UserDefaults.standard.data(forKey: "VisualizerSettings"),
           let settings = try? JSONDecoder().decode(VisualizerSettings.self, from: data) {
            return settings
        }
        return .default
    }
}
