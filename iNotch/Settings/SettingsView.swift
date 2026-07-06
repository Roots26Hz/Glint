import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.hoverDelayKey) private var hoverDelay = 0.2
    @AppStorage(Preferences.notificationDurationKey) private var notificationDuration = 3.5
    @AppStorage(Preferences.lowBatteryThresholdKey) private var lowBatteryThreshold = 20
    @AppStorage(Preferences.musicEnabledKey) private var musicEnabled = true
    @AppStorage(Preferences.batteryEnabledKey) private var batteryEnabled = true
    @AppStorage(Preferences.volumeHUDEnabledKey) private var volumeHUDEnabled = true
    @AppStorage(Preferences.brightnessHUDEnabledKey) private var brightnessHUDEnabled = true
    @AppStorage(Preferences.bluetoothEnabledKey) private var bluetoothEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Show Apple Music live activity", isOn: $musicEnabled)

                HStack {
                    Slider(value: $hoverDelay, in: 0...1, step: 0.05) {
                        Text("Hover expand delay")
                    }
                    Text(String(format: "%.2fs", hoverDelay))
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
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        // Surface the dock icon while settings are open (hidden again by
        // AppDelegate when this window closes).
        .onAppear { DockIcon.show() }
    }
}
