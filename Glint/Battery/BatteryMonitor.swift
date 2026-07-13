import Foundation
import IOKit.ps

enum BatteryEvent: Equatable {
    case pluggedIn(percentage: Int)
    case unplugged(percentage: Int)
    case lowBattery(percentage: Int)
    case fullyCharged(percentage: Int)
    case chargeLimited(percentage: Int)
}

/// Watches IOKit power sources and emits transition events:
/// charger attached, charger detached, battery dropping below the user's
/// low-battery threshold while on battery power, charging completing at
/// 100%, and charging stopping early at the macOS charge limit (or an
/// Optimized Battery Charging hold).
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var percentage = 100
    @Published private(set) var onACPower = true
    @Published private(set) var isCharging = false
    @Published private(set) var isCharged = false

    var onEvent: ((BatteryEvent) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var previousOnAC: Bool?
    private var wasCharging = false
    private var lowBatteryFired = false
    // Charge-complete events fire once per AC session (re-armed on unplug):
    // at the charge limit the battery sails 80 → 78 → 80…, and each top-off
    // must not repeat the banner.
    private var fullChargeFired = false
    private var chargeLimitFired = false
    /// Pending confirmation that a charging stop really is the charge limit
    /// and not a momentary pause (e.g. load exceeding the adapter's wattage).
    private var chargeLimitConfirmWork: DispatchWorkItem?

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
            let newIsCharged = description[kIOPSIsChargedKey] as? Bool ?? false

            apply(
                percentage: newPercentage, onAC: newOnAC, charging: newIsCharging,
                charged: newIsCharged, emitEvents: emitEvents
            )
            return
        }
    }

    /// State-transition core, separated from IOPS parsing so it stays
    /// testable with synthetic states.
    private func apply(
        percentage newPercentage: Int, onAC newOnAC: Bool,
        charging newIsCharging: Bool, charged newIsCharged: Bool, emitEvents: Bool
    ) {
        percentage = newPercentage
        isCharging = newIsCharging
        isCharged = newIsCharged

        let wasOnAC = previousOnAC
        previousOnAC = newOnAC
        onACPower = newOnAC
        let hadBeenCharging = wasCharging
        wasCharging = newIsCharging

        if newOnAC {
            // Plugging in re-arms the low battery alert for the next discharge.
            lowBatteryFired = false
        } else {
            // Unplugging re-arms the charge-complete banners for the next
            // charge session.
            fullChargeFired = false
            chargeLimitFired = false
        }
        if !newOnAC || newIsCharging {
            cancelChargeLimitConfirm()
        }

        guard emitEvents else { return }

        if let wasOnAC, wasOnAC != newOnAC {
            onEvent?(newOnAC ? .pluggedIn(percentage: newPercentage)
                             : .unplugged(percentage: newPercentage))
        } else if !newOnAC, !lowBatteryFired, newPercentage <= Preferences.lowBatteryThreshold {
            lowBatteryFired = true
            onEvent?(.lowBattery(percentage: newPercentage))
        } else if newOnAC, newPercentage >= 100, newIsCharged || !newIsCharging,
                  !fullChargeFired {
            fullChargeFired = true
            onEvent?(.fullyCharged(percentage: newPercentage))
        } else if newOnAC, hadBeenCharging, !newIsCharging, !newIsCharged,
                  Self.chargeLimitBand.contains(newPercentage), !chargeLimitFired {
            scheduleChargeLimitConfirm()
        }
    }

    // MARK: - Charge limit

    /// Where charging stops early on purpose: the macOS charge limit and
    /// Optimized Battery Charging both hold in 80–95%. The floor keeps a
    /// low-level pause (thermal, weak adapter) from being mislabeled.
    private static let chargeLimitBand = 75..<100

    private func scheduleChargeLimitConfirm() {
        guard chargeLimitConfirmWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.chargeLimitConfirmWork = nil
            guard self.onACPower, !self.isCharging, !self.isCharged,
                  Self.chargeLimitBand.contains(self.percentage),
                  !self.chargeLimitFired
            else { return }
            self.chargeLimitFired = true
            self.onEvent?(.chargeLimited(percentage: self.percentage))
        }
        chargeLimitConfirmWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func cancelChargeLimitConfirm() {
        chargeLimitConfirmWork?.cancel()
        chargeLimitConfirmWork = nil
    }
}
