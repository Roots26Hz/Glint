import Foundation
import IOKit.ps

enum BatteryEvent: Equatable {
    case pluggedIn(percentage: Int)
    case unplugged(percentage: Int)
    case lowBattery(percentage: Int)
}

/// Watches IOKit power sources and emits transition events:
/// charger attached, charger detached, and battery dropping below the
/// user's low-battery threshold while on battery power.
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var percentage = 100
    @Published private(set) var onACPower = true
    @Published private(set) var isCharging = false

    var onEvent: ((BatteryEvent) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var previousOnAC: Bool?
    private var lowBatteryFired = false

    init() {
        readPowerState(emitEvents: false)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.readPowerState(emitEvents: true)
            }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }

    private func readPowerState(emitEvents: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        // Find the internal battery. Desktops without one never emit events.
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 100
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let newPercentage = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : 100
            let newOnAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let newIsCharging = description[kIOPSIsChargingKey] as? Bool ?? false

            percentage = newPercentage
            isCharging = newIsCharging

            let wasOnAC = previousOnAC
            previousOnAC = newOnAC
            onACPower = newOnAC

            if newOnAC {
                // Plugging in re-arms the low battery alert for the next discharge.
                lowBatteryFired = false
            }

            guard emitEvents else { return }

            if let wasOnAC, wasOnAC != newOnAC {
                onEvent?(newOnAC ? .pluggedIn(percentage: newPercentage)
                                 : .unplugged(percentage: newPercentage))
            } else if !newOnAC, !lowBatteryFired, newPercentage <= Preferences.lowBatteryThreshold {
                lowBatteryFired = true
                onEvent?(.lowBattery(percentage: newPercentage))
            }
            return
        }
    }
}
