import CoreGraphics
import Foundation

/// A change in the built-in display's brightness.
struct BrightnessEvent: Equatable {
    var level: Float // 0...1
}

/// Watches the built-in display's brightness and reports changes through
/// `onEvent`, mirroring VolumeMonitor's pattern.
///
/// There is no public API for reading built-in display brightness, so the
/// level comes from a read-only call into the private DisplayServices
/// framework (the same value Control Center shows). Brightness has no
/// change-notification API either, so the value is polled on a lightweight
/// timer; if the framework or a built-in display is unavailable, the monitor
/// stays silent.
@MainActor
final class BrightnessMonitor {
    var onEvent: ((BrightnessEvent) -> Void)?

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private let getBrightness: GetBrightness?
    private let displayID: CGDirectDisplayID
    private var lastLevel: Float?
    private var timer: Timer?

    init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        if let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getBrightness = nil
        }

        displayID = Self.builtInDisplayID()

        // Prime the dedupe state so launch doesn't flash a HUD (poll() also
        // suppresses its first successful sample if this read failed).
        lastLevel = readLevel()
        if getBrightness != nil {
            startPolling()
        }
    }

    private static func builtInDisplayID() -> CGDirectDisplayID {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count)
        for display in displays.prefix(Int(count)) where CGDisplayIsBuiltin(display) != 0 {
            return display
        }
        return CGMainDisplayID()
    }

    private func startPolling() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        // .common keeps the poll running while menus/drags hold the run loop.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func readLevel() -> Float? {
        guard let getBrightness else { return nil }
        var level: Float = 0
        guard getBrightness(displayID, &level) == 0 else { return nil }
        return min(max(level, 0), 1)
    }

    private func poll() {
        guard let level = readLevel() else { return }
        // Small epsilon: auto-brightness drifts by tiny amounts constantly
        // and shouldn't pop the HUD; key presses step by 1/16 (~0.06).
        if let last = lastLevel, abs(level - last) < 0.01 { return }
        let isFirst = lastLevel == nil
        lastLevel = level
        if !isFirst {
            onEvent?(BrightnessEvent(level: level))
        }
    }
}
