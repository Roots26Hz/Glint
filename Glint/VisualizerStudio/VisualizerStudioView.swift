import SwiftUI

struct VisualizerStudioView: View {
    @State private var settings = VisualizerSettings.load()
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
                                customSettings: settings
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
                    get: { settings.style },
                    set: { newStyle in
                        if let newStyle = newStyle {
                            settings.style = newStyle
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
                            Picker("Bar Count", selection: $settings.barCount) {
                                Text("16 Bars").tag(16)
                                Text("8 Bars").tag(8)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: settings.barCount) { _ in save() }
                            
                            slider(title: "Animation Speed", value: $settings.animationSpeed)
                            slider(title: "Wave Height", value: $settings.waveHeight)
                            slider(title: "Glow Strength", value: $settings.glowStrength)
                            slider(title: "Thickness", value: $settings.thickness)
                            slider(title: "Sensitivity", value: $settings.sensitivity)
                        }
                        
                        Section("Appearance") {
                            slider(title: "Opacity", value: $settings.opacity)
                            slider(title: "Corner Radius", value: $settings.cornerRadius)
                            slider(title: "Smoothness", value: $settings.smoothness)
                        }
                        
                        Section("Advanced Effects") {
                            slider(title: "Beat Pulse", value: $settings.beatPulseStrength)
                            slider(title: "Reflection", value: $settings.reflectionIntensity)
                            
                            Stepper("Layer Count: \(settings.layerCount)", value: $settings.layerCount, in: 1...10)
                                .onChange(of: settings.layerCount) { _ in save() }
                            
                            Toggle("Mirror Left/Right", isOn: $settings.mirrorLeftRight)
                                .onChange(of: settings.mirrorLeftRight) { _ in save() }
                            
                            Toggle("Center Out Animation", isOn: $settings.centerOutAnimation)
                                .onChange(of: settings.centerOutAnimation) { _ in save() }
                                
                            Toggle("Idle Animation", isOn: $settings.idleAnimation)
                                .onChange(of: settings.idleAnimation) { _ in save() }
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
        settings.save()
    }
}
