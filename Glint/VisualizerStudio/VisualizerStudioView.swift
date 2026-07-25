import SwiftUI

struct VisualizerStudioView: View {
    @ObservedObject private var manager = VisualizerSettingsManager.shared
    @StateObject private var dummyAnalyzer = AudioSpectrumAnalyzer()
    
    private let previewPalette = ColorPalette(
        dominant: Color(red: 0.8, green: 0.2, blue: 0.8),
        secondary: Color(red: 0.7, green: 0.1, blue: 0.7),
        highlight: Color(red: 0.9, green: 0.4, blue: 0.9),
        background: Color(red: 0.1, green: 0.0, blue: 0.1),
        glow: Color(red: 1.0, green: 0.0, blue: 1.0)
    )
    
    var body: some View {
        VStack(spacing: 0) {
            // Live Preview Header
            ZStack {
                Color.black
                
                VStack {
                    Spacer()
                    // Re-use Notch shape for preview enclosure
                    NotchShape(topRadius: 8, bottomRadius: 12)
                        .fill(Color(white: 0.1))
                        .frame(width: 200, height: 32)
                        .overlay {
                            PremiumVisualizerView(
                                isPlaying: true,
                                palette: previewPalette,
                                analyzer: dummyAnalyzer,
                                customSettings: manager.settings
                            )
                            .padding(.horizontal, 20)
                        }
                    Spacer()
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            
            Divider()
            
            HStack(spacing: 0) {
                // Style Selector Sidebar
                List(selection: Binding(
                    get: { manager.settings.style },
                    set: { newStyle in
                        if let newStyle = newStyle {
                            manager.settings.style = newStyle
                            save()
                        }
                    }
                )) {
                    ForEach(VisualizerStyle.allCases) { style in
                        VStack(alignment: .leading) {
                            Text(style.rawValue)
                                .font(.headline)
                            Text(style.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(style)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 250)
                
                Divider()
                
                // Customization Panel
                ScrollView {
                    Form {
                        Section("Core Tuning") {
                            Picker("Bar Count", selection: $manager.settings.barCount) {
                                Text("16 Bars").tag(16)
                                Text("8 Bars").tag(8)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: manager.settings.barCount) { _ in save() }
                            
                            slider(title: "Animation Speed", value: $manager.settings.animationSpeed)
                            slider(title: "Wave Height", value: $manager.settings.waveHeight)
                            slider(title: "Glow Strength", value: $manager.settings.glowStrength)
                            slider(title: "Thickness", value: $manager.settings.thickness)
                            slider(title: "Sensitivity", value: $manager.settings.sensitivity)
                        }
                        
                        Section("Appearance") {
                            slider(title: "Opacity", value: $manager.settings.opacity)
                            slider(title: "Corner Radius", value: $manager.settings.cornerRadius)
                            slider(title: "Smoothness", value: $manager.settings.smoothness)
                        }
                        
                        Section("Advanced Effects") {
                            slider(title: "Beat Pulse", value: $manager.settings.beatPulseStrength)
                            slider(title: "Reflection", value: $manager.settings.reflectionIntensity)
                            
                            Stepper("Layer Count: \(manager.settings.layerCount)", value: $manager.settings.layerCount, in: 1...10)
                                .onChange(of: manager.settings.layerCount) { _ in save() }
                            
                            Toggle("Mirror Left/Right", isOn: $manager.settings.mirrorLeftRight)
                                .onChange(of: manager.settings.mirrorLeftRight) { _ in save() }
                            
                            Toggle("Center Out Animation", isOn: $manager.settings.centerOutAnimation)
                                .onChange(of: manager.settings.centerOutAnimation) { _ in save() }
                                
                            Toggle("Idle Animation", isOn: $manager.settings.idleAnimation)
                                .onChange(of: manager.settings.idleAnimation) { _ in save() }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func slider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Slider(value: value, in: 0...1) { editing in
                if !editing { save() }
            }
        }
    }
    
    private func save() {
        manager.save()
    }
}
