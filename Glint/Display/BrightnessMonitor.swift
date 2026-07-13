import AppKit
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
    /// When a brightness key was last pressed. Polled level changes only
    /// surface as events shortly after a key press, so auto-brightness
    /// (ambient light) adjustments never pop the HUD.
    private var lastKeyPress = Date.distantPast
    private var keyTap: CFMachPort?

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
            // Arm the key tap the moment Accessibility trust exists (the
            // interceptor's bootstrap owns the permission prompt).
            AccessibilityTrust.whenTrusted(promptIfNeeded: false) { [weak self] in
                self?.startKeyMonitor()
            }
        }
    }

    /// Brightness keys arrive as system-defined "aux control button" events;
    /// they are the manual-change signal that gates the HUD. NSEvent's global
    /// monitor never delivers them (verified on macOS 26 even with
    /// Accessibility trust), and listen-only taps additionally demand the
    /// Input Monitoring permission — so use an *active* CGEvent tap, which
    /// the existing Accessibility grant covers, and pass every event through
    /// untouched. Fails soft (the HUD just never appears) without trust.
    private func startKeyMonitor() {
        guard keyTap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, cgEvent, refcon in
            let passthrough = Unmanaged.passUnretained(cgEvent)
            guard let refcon else { return passthrough }
            let monitor = Unmanaged<BrightnessMonitor>.fromOpaque(refcon).takeUnretainedValue()
            // The tap's run-loop source lives on the main run loop, so this
            // callback is main-thread.
            MainActor.assumeIsolated {
                monitor.handleTapEvent(type: type, cgEvent: cgEvent)
            }
            return passthrough
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14), // NX_SYSDEFINED
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        keyTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("Glint: brightness key tap active")
    }

    private func handleTapEvent(type: CGEventType, cgEvent: CGEvent) {
        // The system disables taps it thinks are unresponsive; just re-arm.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let keyTap {
                CGEvent.tapEnable(tap: keyTap, enable: true)
            }
            return
        }
        guard
            let event = NSEvent(cgEvent: cgEvent),
            event.subtype.rawValue == 8 // aux control buttons
        else { return }
        let keyCode = (event.data1 & 0xFFFF_0000) >> 16
        let isKeyDown = (event.data1 & 0x0000_FF00) >> 8 == 0x0A
        // NX_KEYTYPE_BRIGHTNESS_UP = 2, NX_KEYTYPE_BRIGHTNESS_DOWN = 3
        guard isKeyDown, keyCode == 2 || keyCode == 3 else { return }
        lastKeyPress = Date()
    }

    /// MediaKeyInterceptor consumes brightness keys before this monitor's
    /// session-level tap can see them; it reports them here instead so the
    /// HUD gate still opens (and the new level shows immediately).
    func noteBrightnessKey() {
        lastKeyPress = Date()
        poll()
    }

    static func builtInDisplayID() -> CGDirectDisplayID {
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
        // Only changes that closely follow a brightness key press are shown;
        // the 1 s window covers the system's post-press brightness ramp.
        // lastLevel is still updated above so silent auto-brightness drift
        // can't pile up into a later spurious delta.
        if !isFirst, Date().timeIntervalSince(lastKeyPress) < 1.0 {
            onEvent?(BrightnessEvent(level: level))
        }
    }
}
