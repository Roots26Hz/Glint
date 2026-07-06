import Foundation
import IOBluetooth
import IOKit.hid

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
    private let startupGrace = Date().addingTimeInterval(3)

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
        onEvent?(BluetoothEvent(name: name, kind: kind))
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
