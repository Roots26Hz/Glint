import AudioToolbox
import CoreAudio

/// A change in system output volume or mute state.
struct VolumeEvent: Equatable {
    var level: Float // 0...1
    var muted: Bool
}

/// Watches the default output device's volume and mute state via CoreAudio
/// and reports changes through `onEvent`, mirroring BatteryMonitor's pattern.
///
/// macOS still shows its own volume bezel alongside ours; suppressing it
/// would require private OSDUIHelper hacks and is deliberately out of scope.
/// Devices that expose no main volume control (some external DACs) are
/// skipped gracefully — the HUD simply never shows for them.
@MainActor
final class VolumeMonitor {
    var onEvent: ((VolumeEvent) -> Void)?

    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var lastEvent: VolumeEvent?

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static let defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // Listener blocks run on the main dispatch queue (registered with .main),
    // so hopping back onto the main actor is sound.
    private lazy var stateListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        MainActor.assumeIsolated {
            self?.emitCurrentState()
        }
    }
    private lazy var defaultDeviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        MainActor.assumeIsolated {
            self?.attachToDefaultDevice()
        }
    }

    init() {
        var address = Self.defaultOutputAddress
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, defaultDeviceListener
        )
        attachToDefaultDevice()
    }

    private func attachToDefaultDevice() {
        if deviceID != kAudioObjectUnknown {
            var volumeAddress = Self.volumeAddress
            var muteAddress = Self.muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, .main, stateListener)
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, .main, stateListener)
        }

        var address = Self.defaultOutputAddress
        var newID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &newID
        )
        deviceID = newID
        guard deviceID != kAudioObjectUnknown else { return }

        var volumeAddress = Self.volumeAddress
        if AudioObjectHasProperty(deviceID, &volumeAddress) {
            AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, .main, stateListener)
        }
        var muteAddress = Self.muteAddress
        if AudioObjectHasProperty(deviceID, &muteAddress) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, .main, stateListener)
        }

        // Prime the dedupe state so launch / device switches don't flash a HUD.
        lastEvent = readState()
    }

    private func readState() -> VolumeEvent? {
        guard deviceID != kAudioObjectUnknown else { return nil }

        var volumeAddress = Self.volumeAddress
        var volume: Float32 = 0
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &volumeAddress, 0, nil, &volumeSize, &volume
        ) == noErr else { return nil }

        var muteAddress = Self.muteAddress
        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muted)

        return VolumeEvent(level: min(max(volume, 0), 1), muted: muted == 1)
    }

    private func emitCurrentState() {
        // Dedupe so a held key at 0/100% doesn't keep re-firing the HUD.
        guard let event = readState(), event != lastEvent else { return }
        lastEvent = event
        onEvent?(event)
    }
}
