import Foundation

/// Central place for all user preference keys and defaults.
/// Views use @AppStorage with these keys; non-View code reads through the computed properties.
enum Preferences {
    static let hoverDelayKey = "hoverDelay"
    static let notificationDurationKey = "notificationDuration"
    static let lowBatteryThresholdKey = "lowBatteryThreshold"
    static let musicEnabledKey = "musicEnabled"
    static let batteryEnabledKey = "batteryEnabled"
    static let volumeHUDEnabledKey = "volumeHUDEnabled"
    static let brightnessHUDEnabledKey = "brightnessHUDEnabled"
    static let bluetoothEnabledKey = "bluetoothEnabled"

    static let defaults: [String: Any] = [
        hoverDelayKey: 0.2,
        notificationDurationKey: 3.5,
        lowBatteryThresholdKey: 20,
        musicEnabledKey: true,
        batteryEnabledKey: true,
        volumeHUDEnabledKey: true,
        brightnessHUDEnabledKey: true,
        bluetoothEnabledKey: true,
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

    static var bluetoothEnabled: Bool {
        UserDefaults.standard.bool(forKey: bluetoothEnabledKey)
    }
}
