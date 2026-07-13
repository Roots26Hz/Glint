import AppKit
import ApplicationServices

/// One place for Accessibility-trust bootstrapping: run a closure now if the
/// process is trusted, otherwise (optionally) show the system permission
/// prompt and keep re-checking — via the TCC change notification plus a slow
/// fallback timer — until trust appears. Grants picked up live; no relaunch.
@MainActor
enum AccessibilityTrust {
    private final class Watcher {
        var timer: Timer?
        var observer: NSObjectProtocol?
    }

    private static var watchers: [Watcher] = []

    /// Calls `then` once, as soon as the process is trusted (immediately when
    /// it already is). `promptIfNeeded` shows the standard macOS dialog once.
    static func whenTrusted(promptIfNeeded: Bool, then: @escaping @MainActor () -> Void) {
        if AXIsProcessTrusted() {
            then()
            return
        }
        if promptIfNeeded {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }

        let watcher = Watcher()
        watchers.append(watcher)

        let fire: @MainActor () -> Void = { [weak watcher] in
            guard let watcher, AXIsProcessTrusted() else { return }
            watcher.timer?.invalidate()
            if let observer = watcher.observer {
                DistributedNotificationCenter.default().removeObserver(observer)
            }
            watchers.removeAll { $0 === watcher }
            then()
        }

        // Fires when the TCC accessibility list changes (undocumented but
        // long-stable); re-check after a beat so TCC has settled.
        watcher.observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil, queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { fire() }
            }
        }
        // Reliable fallback for when the notification doesn't arrive.
        watcher.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in fire() }
        }
    }
}
