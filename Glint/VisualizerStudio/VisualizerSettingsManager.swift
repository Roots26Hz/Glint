import SwiftUI

@MainActor
final class VisualizerSettingsManager: ObservableObject {
    static let shared = VisualizerSettingsManager()
    
    @Published var settings: VisualizerSettings
    
    private init() {
        self.settings = VisualizerSettings.load()
    }
    
    func save() {
        settings.save()
    }
}
