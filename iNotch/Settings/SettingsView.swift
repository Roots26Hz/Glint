import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            VisualizerStudioView()
                .tabItem {
                    Label("Visualizer Studio", systemImage: "wand.and.stars")
                }
        }
        .frame(width: 600, height: 600)
        .onAppear { DockIcon.show() }
    }
}

struct GeneralSettingsView: View {
    @AppStorage(Preferences.hoverDelayKey) private var hoverDelay = 0.2
    @AppStorage(Preferences.notificationDurationKey) private var notificationDuration = 3.5
    @AppStorage(Preferences.lowBatteryThresholdKey) private var lowBatteryThreshold = 20
    @AppStorage(Preferences.musicEnabledKey) private var musicEnabled = true
    @AppStorage(Preferences.batteryEnabledKey) private var batteryEnabled = true
    @AppStorage(Preferences.volumeHUDEnabledKey) private var volumeHUDEnabled = true
    @AppStorage(Preferences.brightnessHUDEnabledKey) private var brightnessHUDEnabled = true
    @AppStorage(Preferences.hideSystemHUDKey) private var hideSystemHUD = true
    @AppStorage(Preferences.bluetoothEnabledKey) private var bluetoothEnabled = true
    @AppStorage(Preferences.musicWaveStyleKey) private var musicWaveStyle = Preferences.musicWaveStyleEqualizer
    @AppStorage(Preferences.musicLingerDurationKey) private var musicLingerDuration = 120.0

    var body: some View {
        Form {
            Section {
                Toggle("Show Apple Music live activity", isOn: $musicEnabled)

                Picker("Soundwave style", selection: $musicWaveStyle) {
                    Text("Equalizer (live audio)").tag(Preferences.musicWaveStyleEqualizer)
                    Text("Visualizer (animated)").tag(Preferences.musicWaveStyleVisualizer)
                }

                HStack {
                    Slider(value: $hoverDelay, in: 0...1, step: 0.05) {
                        Text("Hover expand delay")
                    }
                    Text(String(format: "%.2fs", hoverDelay))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Slider(value: $musicLingerDuration, in: 15...300, step: 15) {
                        Text("Keep paused player visible")
                    }
                    Text(Self.minutesSeconds(musicLingerDuration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            } header: {
                Label("Music", systemImage: "music.note")
            }

            Section {
                Toggle("Show volume changes in the notch", isOn: $volumeHUDEnabled)
            } header: {
                Label("Volume", systemImage: "speaker.wave.2.fill")
            }

            Section {
                Toggle("Show brightness changes in the notch", isOn: $brightnessHUDEnabled)
            } header: {
                Label("Display", systemImage: "sun.max.fill")
            }

            Section {
                Toggle("Hide the system volume/brightness overlay", isOn: $hideSystemHUD)
                Text("iNotch handles the volume and brightness keys itself, so macOS never shows its own overlay under the menu bar — the notch HUDs are the only ones. Needs the Accessibility permission; takes effect immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("System overlay", systemImage: "rectangle.slash")
            }

            Section {
                Toggle("Show Bluetooth connections", isOn: $bluetoothEnabled)
            } header: {
                Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
            }

            Section {
                Toggle("Show battery notifications", isOn: $batteryEnabled)

                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(lowBatteryThreshold) },
                            set: { lowBatteryThreshold = Int($0) }
                        ),
                        in: 5...90, step: 5
                    ) {
                        Text("Low battery alert at")
                    }
                    Text("\(lowBatteryThreshold)%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Slider(value: $notificationDuration, in: 1...10, step: 0.5) {
                        Text("Notification duration")
                    }
                    Text(String(format: "%.1fs", notificationDuration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            } header: {
                Label("Battery", systemImage: "battery.100percent")
            }
        }
        .formStyle(.grouped)
    }

    private static func minutesSeconds(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
