import AppKit
import SwiftUI

@main
struct GlintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Glint", image: "MenuBarIcon") {
            MenuBarPanel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// The menu-bar panel: a mini control center rather than a plain menu —
/// switches with tinted glyphs, live sliders, and a segmented style picker.
/// "More Settings…" opens the full window for everything else.
private struct MenuBarPanel: View {
    @AppStorage(Preferences.musicEnabledKey) private var musicEnabled = true
    @AppStorage(Preferences.volumeHUDEnabledKey) private var volumeHUDEnabled = true
    @AppStorage(Preferences.brightnessHUDEnabledKey) private var brightnessHUDEnabled = true
    @AppStorage(Preferences.hideSystemHUDKey) private var hideSystemHUD = true
    @AppStorage(Preferences.bluetoothEnabledKey) private var bluetoothEnabled = true
    @AppStorage(Preferences.batteryEnabledKey) private var batteryEnabled = true
    @AppStorage(Preferences.musicWaveStyleKey) private var musicWaveStyle = Preferences.musicWaveStyleEqualizer
    @AppStorage(Preferences.hoverDelayKey) private var hoverDelay = 0.2
    @AppStorage(Preferences.notificationDurationKey) private var notificationDuration = 3.5
    @AppStorage(Preferences.lowBatteryThresholdKey) private var lowBatteryThreshold = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 8) {
                switchRow("music.note", .pink, "Music Live Activity", $musicEnabled)
                switchRow("speaker.wave.2.fill", .blue, "Volume HUD", $volumeHUDEnabled)
                switchRow("sun.max.fill", .yellow, "Brightness HUD", $brightnessHUDEnabled)
                switchRow("rectangle.slash.fill", .purple, "Hide System Overlay", $hideSystemHUD)
                switchRow("antenna.radiowaves.left.and.right", .cyan, "Bluetooth Banners", $bluetoothEnabled)
                switchRow("battery.100percent.bolt", .green, "Battery Notifications", $batteryEnabled)
            }

            Divider()

            sliderRow(
                "cursorarrow.motionlines", "Hover expand delay",
                value: $hoverDelay, in: 0...1, step: 0.05,
                label: String(format: "%.2fs", hoverDelay)
            )
            sliderRow(
                "timer", "Notification duration",
                value: $notificationDuration, in: 1...10, step: 0.5,
                label: String(format: "%.1fs", notificationDuration)
            )
            sliderRow(
                "battery.25percent", "Low battery alert",
                value: Binding(
                    get: { Double(lowBatteryThreshold) },
                    set: { lowBatteryThreshold = Int($0) }
                ), in: 5...90, step: 5,
                label: "\(lowBatteryThreshold)%"
            )

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("SOUNDWAVE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $musicWaveStyle) {
                    Text("Equalizer").tag(Preferences.musicWaveStyleEqualizer)
                    Text("Visualizer").tag(Preferences.musicWaveStyleVisualizer)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            HStack(spacing: 10) {
                SettingsLink {
                    Label("More Settings…", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(",")
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .frame(width: 18, height: 18)
                }
                .keyboardShortcut("q")
                .controlSize(.large)
                .buttonStyle(.bordered)
                .help("Quit Glint")
            }
        }
        .padding(16)
        .frame(width: 312)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text("Glint")
                    .font(.system(size: 14, weight: .semibold))
                Text("The notch, earning its keep")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("v1.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func switchRow(
        _ symbol: String, _ tint: Color, _ title: String, _ isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private func sliderRow(
        _ symbol: String, _ title: String,
        value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
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

        // Launch greeting: "Glint." writes itself into a card that drops
        // from the notch, then dismisses like any other transient.
        viewModel.showGreeting()

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
