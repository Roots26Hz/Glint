import AppKit
import Combine
import SwiftUI

/// What the notch is currently showing.
enum NotchMode: Equatable {
    case idle
    case compactMusic
    case expandedMusic
    case batteryAlert(BatteryEvent)
    case volumeHUD(VolumeEvent)
    case brightnessHUD(BrightnessEvent)
    case bluetoothConnected(BluetoothEvent)
}

/// State machine driving the notch UI:
/// idle → compactMusic (music playing) → expandedMusic (hover — even while
/// paused, so playback can be resumed from the notch), with batteryAlert and
/// volumeHUD as temporary auto-dismissing overlay states.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var mode: NotchMode = .idle
    @Published var isHovering = false

    /// Size of the hardware notch, set by NotchWindowController at launch.
    var notchSize = CGSize(width: 200, height: 32)

    let music: MusicPlayerService
    let battery: BatteryMonitor
    let volume: VolumeMonitor
    let brightness: BrightnessMonitor
    let bluetooth: BluetoothMonitor

    private var hoverWork: DispatchWorkItem?
    private var transientDismissWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(
        music: MusicPlayerService, battery: BatteryMonitor, volume: VolumeMonitor,
        brightness: BrightnessMonitor, bluetooth: BluetoothMonitor
    ) {
        self.music = music
        self.battery = battery
        self.volume = volume
        self.brightness = brightness
        self.bluetooth = bluetooth

        music.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshMode() }
            .store(in: &cancellables)

        battery.onEvent = { [weak self] event in
            self?.showBatteryAlert(event)
        }
        volume.onEvent = { [weak self] event in
            self?.showVolumeHUD(event)
        }
        brightness.onEvent = { [weak self] event in
            self?.showBrightnessHUD(event)
        }
        bluetooth.onEvent = { [weak self] event in
            self?.showBluetoothBanner(event)
        }
    }

    // MARK: - Sizing

    /// Content size for each mode. The panel window is fixed at the max of
    /// these; the black shape animates between them.
    var contentSize: CGSize {
        switch mode {
        case .idle:
            return notchSize
        case .compactMusic:
            return CGSize(width: notchSize.width + 130, height: notchSize.height)
        case .expandedMusic:
            return CGSize(width: max(notchSize.width + 300, 480), height: notchSize.height + 138)
        case .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected:
            return CGSize(width: notchSize.width + 230, height: notchSize.height)
        }
    }

    static func maxPanelSize(for notch: CGSize) -> CGSize {
        CGSize(width: max(notch.width + 340, 560), height: notch.height + 190)
    }

    // MARK: - Hover

    func hoverChanged(_ hovering: Bool) {
        hoverWork?.cancel()
        // Both directions are debounced: entry by the user's hover delay,
        // exit by a short grace period so grazing the panel edge doesn't
        // flicker the player closed and open again.
        let delay = hovering ? Preferences.hoverDelay : 0.15
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isHovering = hovering
            self.refreshMode()
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Transient alerts

    /// True while a battery alert or volume HUD is on screen waiting for its
    /// dismiss timer; regular mode resolution is deferred until it fires.
    private var isTransientActive: Bool {
        guard transientDismissWork != nil else { return false }
        switch mode {
        case .batteryAlert, .volumeHUD, .brightnessHUD, .bluetoothConnected: return true
        default: return false
        }
    }

    private func showBatteryAlert(_ event: BatteryEvent) {
        guard Preferences.batteryEnabled else { return }
        setMode(.batteryAlert(event))
        scheduleTransientDismiss(after: Preferences.notificationDuration)
    }

    private func showVolumeHUD(_ event: VolumeEvent) {
        guard Preferences.volumeHUDEnabled else { return }
        // Don't yank the expanded player out from under the cursor.
        if mode == .expandedMusic { return }
        setMode(.volumeHUD(event))
        scheduleTransientDismiss(after: 1.5)
    }

    private func showBrightnessHUD(_ event: BrightnessEvent) {
        guard Preferences.brightnessHUDEnabled else { return }
        if mode == .expandedMusic { return }
        setMode(.brightnessHUD(event))
        scheduleTransientDismiss(after: 1.5)
    }

    private func showBluetoothBanner(_ event: BluetoothEvent) {
        guard Preferences.bluetoothEnabled else { return }
        if mode == .expandedMusic { return }
        setMode(.bluetoothConnected(event))
        scheduleTransientDismiss(after: Preferences.notificationDuration)
    }

    /// Between the two transients, latest wins: each call replaces the mode
    /// and restarts the timer.
    private func scheduleTransientDismiss(after delay: TimeInterval) {
        transientDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.transientDismissWork = nil
            self.refreshMode()
        }
        transientDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Mode resolution

    func refreshMode() {
        // A battery alert or volume HUD stays up until its timer fires.
        if isTransientActive { return }

        guard Preferences.musicEnabled else {
            setMode(.idle)
            return
        }
        if isHovering {
            // Expands even while paused/stopped so play is always reachable.
            setMode(.expandedMusic)
        } else if music.isPlaying {
            setMode(.compactMusic)
        } else {
            setMode(.idle)
        }
    }

    private func setMode(_ newMode: NotchMode) {
        guard newMode != mode else { return }
        withAnimation(Self.animation(from: mode, to: newMode)) {
            mode = newMode
        }
        music.setExpanded(newMode == .expandedMusic)
    }

    /// One curve per kind of transition: repeated HUD keypresses track
    /// instantly, anything shrinking settles without bounce, and growth gets
    /// a gentle spring.
    private static func animation(from old: NotchMode, to new: NotchMode) -> Animation {
        switch (old, new) {
        case (.volumeHUD, .volumeHUD), (.brightnessHUD, .brightnessHUD):
            return .easeOut(duration: 0.12)
        case (_, .idle), (.expandedMusic, .compactMusic):
            return .smooth(duration: 0.32)
        default:
            return .spring(response: 0.45, dampingFraction: 0.85)
        }
    }
}
