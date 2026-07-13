import AppKit
import CoreAudio
import CoreGraphics
import Foundation

/// Hides the macOS volume/brightness overlay (the Control Center pill under
/// the menu bar) by consuming the media keys before the system sees them:
/// an active CGEvent tap at the HID level swallows volume/brightness key
/// events and applies the change itself — CoreAudio for volume,
/// DisplayServices for brightness. With no key event to react to, macOS
/// never draws its overlay, and Glint's notch HUDs fire through the
/// existing volume listener / brightness poll.
///
/// Gated per event on `Preferences.hideSystemHUD`, so the Settings toggle
/// takes effect instantly with no re-wiring. Fails soft everywhere: without
/// Accessibility trust the tap never comes up, and any key whose value can't
/// be adjusted (an output device with no volume control, a display
/// DisplayServices can't dim) passes through for the system to handle.
/// The tap dies with the process, so quitting Glint needs no cleanup.
@MainActor
final class MediaKeyInterceptor {
    /// Called after a consumed volume key, even when the level didn't move
    /// (already at 0 or 100% — the HUD should still show, and no CoreAudio
    /// change notification will fire).
    var onVolumeChange: (() -> Void)?
    /// Called after a consumed brightness key: BrightnessMonitor's own tap
    /// never sees consumed events, so its HUD gate must be opened directly.
    var onBrightnessChange: (() -> Void)?

    // NX aux-key codes (IOKit/hidsystem/ev_keymap.h).
    private static let soundUp = 0, soundDown = 1
    private static let brightnessUp = 2, brightnessDown = 3
    private static let mute = 7

    private var tap: CFMachPort?
    /// Whether the last key-down of each code was consumed, so the matching
    /// key-up is swallowed or passed the same way.
    private var downConsumed: [Int: Bool] = [:]

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private let displayID: CGDirectDisplayID

    /// The click macOS plays for volume keys when "Play feedback when volume
    /// is changed" is on; consumed keys have to play it themselves.
    private let feedbackSound = NSSound(
        contentsOfFile:
            "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff",
        byReference: true
    )

    init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        if let handle,
           let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
           let setSymbol = dlsym(handle, "DisplayServicesSetBrightness") {
            getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
            setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
        } else {
            getBrightness = nil
            setBrightness = nil
        }
        displayID = BrightnessMonitor.builtInDisplayID()
        // Prompt only when the feature is on; arm the tap the moment
        // Accessibility trust appears — no relaunch needed.
        AccessibilityTrust.whenTrusted(promptIfNeeded: Preferences.hideSystemHUD) { [weak self] in
            self?.startTap()
        }
    }

    // MARK: - Event tap

    private func startTap() {
        guard tap == nil, AXIsProcessTrusted() else { return }

        let callback: CGEventTapCallBack = { _, type, cgEvent, refcon in
            let passthrough = Unmanaged.passUnretained(cgEvent)
            guard let refcon else { return passthrough }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            // The tap's run-loop source lives on the main run loop, so this
            // callback is main-thread.
            let consumed = MainActor.assumeIsolated {
                interceptor.handleTapEvent(type: type, cgEvent: cgEvent)
            }
            return consumed ? nil : passthrough
        }
        // HID-level (not session-level like BrightnessMonitor's listen tap):
        // a consumed event must vanish before anything else — Control Center
        // included — can react to it.
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14), // NX_SYSDEFINED
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("Glint: media-key tap active")
    }

    /// Returns true when the event was handled and must be swallowed.
    private func handleTapEvent(type: CGEventType, cgEvent: CGEvent) -> Bool {
        // The system disables taps it thinks are unresponsive; just re-arm.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return false
        }
        guard
            Preferences.hideSystemHUD,
            let event = NSEvent(cgEvent: cgEvent),
            event.subtype.rawValue == 8 // aux control buttons
        else { return false }

        let keyCode = Int((event.data1 & 0xFFFF_0000) >> 16)
        let isKeyDown = (event.data1 & 0x0000_FF00) >> 8 == 0x0A
        guard isKeyDown else {
            // Key-up: mirror whatever happened to its key-down, so the
            // system never sees half a press.
            return downConsumed[keyCode] ?? false
        }

        let consumed: Bool
        switch keyCode {
        case Self.soundUp, Self.soundDown:
            consumed = stepVolume(up: keyCode == Self.soundUp, flags: event.modifierFlags)
        case Self.mute:
            consumed = toggleMute()
        case Self.brightnessUp, Self.brightnessDown:
            consumed = stepBrightness(up: keyCode == Self.brightnessUp, flags: event.modifierFlags)
        default:
            return false
        }
        downConsumed[keyCode] = consumed
        return consumed
    }

    /// Option+Shift steps by quarter-segments, like the hardware keys do.
    private static func step(for flags: NSEvent.ModifierFlags) -> Float {
        flags.contains(.option) && flags.contains(.shift) ? 1 / 64 : 1 / 16
    }

    // MARK: - Volume

    private func stepVolume(up: Bool, flags: NSEvent.ModifierFlags) -> Bool {
        guard let deviceID = Self.defaultOutputDevice(),
              let volume = Self.readFloat(deviceID, VolumeMonitor.volumeAddress)
        else { return false }

        let target = min(max(volume + (up ? 1 : -1) * Self.step(for: flags), 0), 1)
        guard Self.write(target, deviceID, VolumeMonitor.volumeAddress) else { return false }
        if up {
            // Volume-up unmutes, matching the system's key handling.
            _ = Self.write(UInt32(0), deviceID, VolumeMonitor.muteAddress)
        }
        playFeedbackIfWanted(flags: flags)
        onVolumeChange?()
        return true
    }

    private func toggleMute() -> Bool {
        guard let deviceID = Self.defaultOutputDevice(),
              let muted = Self.readUInt32(deviceID, VolumeMonitor.muteAddress),
              Self.write(UInt32(muted == 0 ? 1 : 0), deviceID, VolumeMonitor.muteAddress)
        else { return false }
        onVolumeChange?()
        return true
    }

    private func playFeedbackIfWanted(flags: NSEvent.ModifierFlags) {
        // Fine stepping is silent; Shift inverts the user's feedback pref.
        if flags.contains(.option), flags.contains(.shift) { return }
        let prefOn = (UserDefaults.standard
            .object(forKey: "com.apple.sound.beep.feedback") as? NSNumber)?.intValue == 1
        guard prefOn != flags.contains(.shift), let feedbackSound else { return }
        feedbackSound.stop()
        feedbackSound.play()
    }

    // MARK: - Brightness

    private func stepBrightness(up: Bool, flags: NSEvent.ModifierFlags) -> Bool {
        guard let getBrightness, let setBrightness else { return false }
        var level: Float = 0
        guard getBrightness(displayID, &level) == 0 else { return false }
        let target = min(max(level + (up ? 1 : -1) * Self.step(for: flags), 0), 1)
        guard setBrightness(displayID, target) == 0 else { return false }
        onBrightnessChange?()
        return true
    }

    // MARK: - CoreAudio plumbing

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = VolumeMonitor.defaultOutputAddress
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func readFloat(
        _ deviceID: AudioDeviceID, _ address: AudioObjectPropertyAddress
    ) -> Float? {
        var address = address
        var value: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value
    }

    private static func readUInt32(
        _ deviceID: AudioDeviceID, _ address: AudioObjectPropertyAddress
    ) -> UInt32? {
        var address = address
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectHasProperty(deviceID, &address),
              AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value
    }

    private static func write(
        _ value: Float, _ deviceID: AudioDeviceID, _ address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        var value = value
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        let size = UInt32(MemoryLayout<Float>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value) == noErr
    }

    private static func write(
        _ value: UInt32, _ deviceID: AudioDeviceID, _ address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        var value = value
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value) == noErr
    }
}
