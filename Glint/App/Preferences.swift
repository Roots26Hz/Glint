import Foundation

/// Central place for all user preference keys and defaults.
/// Views use @AppStorage with these keys; non-View code reads through the computed properties.
enum Preferences {
    static let hoverDelayKey = "hoverDelay"
    static let notificationDurationKey = "notificationDuration"
    /// How long the paused live activity keeps showing before the notch idles.
    static let musicLingerDurationKey = "musicLingerDuration"
    static let lowBatteryThresholdKey = "lowBatteryThreshold"
    static let musicEnabledKey = "musicEnabled"
    static let batteryEnabledKey = "batteryEnabled"
    static let volumeHUDEnabledKey = "volumeHUDEnabled"
    static let brightnessHUDEnabledKey = "brightnessHUDEnabled"
    /// Consume volume/brightness keys and handle them in-app so the macOS
    /// overlay never appears — only the notch HUDs show.
    static let hideSystemHUDKey = "hideSystemHUD"
    static let bluetoothEnabledKey = "bluetoothEnabled"
    /// "equalizer" (audio-reactive) or "visualizer" (procedural animation).
    static let musicWaveStyleKey = "musicWaveStyle"

    static let musicWaveStyleEqualizer = "equalizer"
    static let musicWaveStyleVisualizer = "visualizer"

    static let defaults: [String: Any] = [
        hoverDelayKey: 0.2,
        notificationDurationKey: 3.5,
        musicLingerDurationKey: 120.0,
        lowBatteryThresholdKey: 20,
        musicEnabledKey: true,
        batteryEnabledKey: true,
        volumeHUDEnabledKey: true,
        brightnessHUDEnabledKey: true,
        hideSystemHUDKey: true,
        bluetoothEnabledKey: true,
        musicWaveStyleKey: musicWaveStyleEqualizer,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    static var hoverDelay: TimeInterval {
        UserDefaults.standard.double(forKey: hoverDelayKey)
    }

    static var notificationDuration: TimeInterval {
        UserDefaults.standard.double(forKey: notificationDurationKey)
    }

    static var musicLingerDuration: TimeInterval {
        UserDefaults.standard.double(forKey: musicLingerDurationKey)
    }

    static var lowBatteryThreshold: Int {
        UserDefaults.standard.integer(forKey: lowBatteryThresholdKey)
    }

    static var musicEnabled: Bool {
        UserDefaults.standard.bool(forKey: musicEnabledKey)
    }

    static var batteryEnabled: Bool {
        UserDefaults.standard.bool(forKey: batteryEnabledKey)
    }

    static var volumeHUDEnabled: Bool {
        UserDefaults.standard.bool(forKey: volumeHUDEnabledKey)
    }

    static var brightnessHUDEnabled: Bool {
        UserDefaults.standard.bool(forKey: brightnessHUDEnabledKey)
    }

    static var hideSystemHUD: Bool {
        UserDefaults.standard.bool(forKey: hideSystemHUDKey)
    }

    static var bluetoothEnabled: Bool {
        UserDefaults.standard.bool(forKey: bluetoothEnabledKey)
    }

    static var musicWaveStyle: String {
        UserDefaults.standard.string(forKey: musicWaveStyleKey) ?? musicWaveStyleEqualizer
    }
}
