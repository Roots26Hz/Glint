import Foundation
import IOBluetooth
import IOKit
import IOKit.hid
import IOKit.ps

/// A Bluetooth device that just connected.
struct BluetoothEvent: Equatable {
    enum Kind: Equatable {
        case headphones
        case keyboard
        case mouse
        case generic
    }

    var name: String
    var kind: Kind
    /// 0…100, nil when the device doesn't report a battery level.
    var battery: Int?
}

/// Watches for Bluetooth device connections and reports them through
/// `onEvent`, mirroring BatteryMonitor's pattern. Two complementary sources:
///
/// - IOBluetooth connect notifications for classic Bluetooth (headphones,
///   AirPods, older peripherals). Registering triggers the system's
///   Bluetooth privacy prompt (NSBluetoothAlwaysUsageDescription).
/// - IOHIDManager device-arrival callbacks for HID peripherals — this is
///   what catches BLE-only keyboards and mice, which never emit classic
///   connect notifications.
///
/// Both paths funnel through one name-keyed dedupe so a classic HID device
/// seen by both doesn't banner twice.
@MainActor
final class BluetoothMonitor: NSObject {
    var onEvent: ((BluetoothEvent) -> Void)?

    /// Name → last banner time; reconnect storms and multi-interface HID
    /// devices (one physical device, several HID services) shouldn't spam.
    private var recentlyAnnounced: [String: Date] = [:]
    private var hidManager: IOHIDManager?
    /// Devices already connected at launch enumerate in a burst right after
    /// the HID manager opens; anything inside this window is not "news".
    /// (5 s: the 3 s window was occasionally outrun by app launch, making a
    /// connected headset banner on every start.)
    private let startupGrace = Date().addingTimeInterval(5)

    override init() {
        super.init()
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        startHIDMonitor()
    }

    private func announce(name: String, kind: BluetoothEvent.Kind) {
        let now = Date()
        if let last = recentlyAnnounced[name], now.timeIntervalSince(last) < 5 { return }
        recentlyAnnounced[name] = now
        // The battery level (shown like the iOS pairing banner) usually lands
        // in the IORegistry a moment after the connection, so retry briefly
        // before showing the banner without it.
        Task { [weak self] in
            var battery = Self.batteryPercent(matching: name)
            var attempts = 0
            while battery == nil, attempts < 5 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                battery = Self.batteryPercent(matching: name)
                attempts += 1
            }
            self?.onEvent?(BluetoothEvent(name: name, kind: kind, battery: battery))
        }
    }

    // MARK: - Battery level

    /// Battery percentage for a connected Bluetooth device, matched by name.
    ///
    /// Most devices (third-party mice, keyboards, headsets) surface their
    /// level as an accessory power source, so IOPowerSources is checked
    /// first; the AppleDeviceManagementHIDEventService registry walk remains
    /// as the fallback because it is the only place AirPods publish their
    /// per-ear Left/Right values.
    private static func batteryPercent(matching name: String) -> Int? {
        accessoryPowerSourcePercent(matching: name)
            ?? deviceManagementPercent(matching: name)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Accessory power sources (what `pmset -g accps` lists) are not part of
    /// the public IOPSCopyPowerSourcesList, so this goes through the private
    /// accessories filter of IOPSCopyPowerSourcesByType — same read-only,
    /// fail-to-nil pattern as BrightnessMonitor's DisplayServices call.
    private typealias CopyPowerSourcesByType = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let copyPowerSourcesByType: CopyPowerSourcesByType? = {
        guard
            let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
            let symbol = dlsym(handle, "IOPSCopyPowerSourcesByType")
        else { return nil }
        return unsafeBitCast(symbol, to: CopyPowerSourcesByType.self)
    }()
    private static let accessorySourcesFilter: Int32 = 4 // kIOPSSourceForAccessories

    private static func accessoryPowerSourcePercent(matching name: String) -> Int? {
        guard
            let copyPowerSourcesByType,
            let sources = copyPowerSourcesByType(accessorySourcesFilter)?
                .takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let wanted = normalized(name)

        for description in sources {
            guard
                let sourceName = description[kIOPSNameKey] as? String,
                normalized(sourceName) == wanted,
                let current = description[kIOPSCurrentCapacityKey] as? Int
            else { continue }
            // Accessories report capacity as 0-100, but scale defensively.
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
            guard maxCapacity > 0 else { continue }
            return min(max(current * 100 / maxCapacity, 0), 100)
        }
        return nil
    }

    private static func deviceManagementPercent(matching name: String) -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"),
            &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }
        let wanted = normalized(name)

        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { return nil }
            defer { IOObjectRelease(entry) }

            guard
                let product = property(entry, "Product") as? String,
                normalized(product) == wanted
            else { continue }
            if let percent = property(entry, "BatteryPercent") as? Int {
                return min(max(percent, 0), 100)
            }
            let left = property(entry, "BatteryPercentLeft") as? Int
            let right = property(entry, "BatteryPercentRight") as? Int
            if left != nil || right != nil {
                return min(max(left ?? 0, right ?? 0), 100)
            }
        }
    }

    // MARK: - Classic Bluetooth (IOBluetooth)

    // IOBluetooth delivers connect notifications on the main run loop.
    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification, device: IOBluetoothDevice
    ) {
        announce(name: device.name ?? "Bluetooth Device", kind: Self.kind(of: device))
    }

    private static func kind(of device: IOBluetoothDevice) -> BluetoothEvent.Kind {
        switch device.deviceClassMajor {
        case UInt32(kBluetoothDeviceClassMajorAudio):
            return .headphones
        case UInt32(kBluetoothDeviceClassMajorPeripheral):
            // Bits 5-4 of the minor class: 01 keyboard, 10 pointing, 11 combo.
            switch device.deviceClassMinor & 0x30 {
            case UInt32(kBluetoothDeviceClassMinorPeripheral1Keyboard),
                 UInt32(kBluetoothDeviceClassMinorPeripheral1Combo):
                return .keyboard
            case UInt32(kBluetoothDeviceClassMinorPeripheral1Pointing):
                return .mouse
            default:
                return .generic
            }
        default:
            return .generic
        }
    }

    // MARK: - BLE HID peripherals (IOHIDManager)

    private func startHIDMonitor() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let monitor = Unmanaged<BluetoothMonitor>.fromOpaque(context).takeUnretainedValue()
            // Scheduled on the main run loop, so this lands on the main thread.
            MainActor.assumeIsolated {
                monitor.hidDeviceArrived(device)
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager
    }

    private func hidDeviceArrived(_ device: IOHIDDevice) {
        guard Date() > startupGrace else { return }
        guard
            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
            transport.localizedCaseInsensitiveContains("bluetooth")
        else { return }
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
        announce(name: name ?? "Bluetooth Device", kind: Self.hidKind(of: device))
    }

    private static func hidKind(of device: IOHIDDevice) -> BluetoothEvent.Kind {
        func conforms(to usage: Int) -> Bool {
            IOHIDDeviceConformsTo(device, UInt32(kHIDPage_GenericDesktop), UInt32(usage))
        }
        if conforms(to: kHIDUsage_GD_Keyboard) || conforms(to: kHIDUsage_GD_Keypad) {
            return .keyboard
        }
        if conforms(to: kHIDUsage_GD_Mouse) || conforms(to: kHIDUsage_GD_Pointer) {
            return .mouse
        }
        return .generic
    }
}
