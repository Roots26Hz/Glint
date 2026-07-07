import AppKit
import SwiftUI

@main
struct iNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("iNotch", image: "MenuBarIcon") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit iNotch") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}

/// The app runs as an accessory (LSUIElement — no dock icon). The dock icon
/// appears only while the Settings window is open: SettingsView calls
/// `show()` on appear, and AppDelegate flips back to accessory when the
/// settings window closes.
@MainActor
enum DockIcon {
    static var settingsWindow: NSWindow? {
        NSApp.windows.first { isSettingsWindow($0) }
    }

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.contains("Settings") == true
    }

    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Opened from an accessory-mode menu bar extra, the settings window
        // can land behind other apps; bring it forward explicitly.
        DispatchQueue.main.async {
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    static func hide() {
        NSApp.setActivationPolicy(.accessory)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var viewModel: NotchViewModel?
    private var mediaKeyInterceptor: MediaKeyInterceptor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()

        let music = MusicPlayerService()
        let battery = BatteryMonitor()
        let volume = VolumeMonitor()
        let brightness = BrightnessMonitor()
        let bluetooth = BluetoothMonitor()
        let viewModel = NotchViewModel(
            music: music, battery: battery, volume: volume,
            brightness: brightness, bluetooth: bluetooth
        )
        self.viewModel = viewModel
        windowController = NotchWindowController(viewModel: viewModel)

        // Consumes volume/brightness keys (when enabled) so the system
        // overlay never appears; the notch HUDs are driven through the
        // monitors' usual paths.
        let interceptor = MediaKeyInterceptor()
        interceptor.onVolumeChange = { [weak volume] in volume?.showCurrentState() }
        interceptor.onBrightnessChange = { [weak brightness] in brightness?.noteBrightnessKey() }
        mediaKeyInterceptor = interceptor

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard DockIcon.isSettingsWindow(window) else { return }
                // Drop back to accessory after the close finishes.
                DispatchQueue.main.async { DockIcon.hide() }
            }
        }
    }

    /// Clicking the dock icon (visible only while Settings is open) brings
    /// the settings window back to the front.
    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows: Bool
    ) -> Bool {
        DockIcon.settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
}
