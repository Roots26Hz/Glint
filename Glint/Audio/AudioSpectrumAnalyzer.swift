import Accelerate
import AppKit
import CoreAudio
import Foundation

struct SpectrumData: Equatable {
    var levels: [Float]
    var bassEnergy: Float
    var midEnergy: Float
    var trebleEnergy: Float
    var beatImpulse: Float
    static let empty = SpectrumData(levels: [Float](repeating: 0, count: 16), bassEnergy: 0, midEnergy: 0, trebleEnergy: 0, beatImpulse: 0)
    
    func levels(for count: Int) -> [Float] {
        if count == 8 && levels.count == 16 {
            return (0..<8).map { (levels[$0 * 2] + levels[$0 * 2 + 1]) / 2.0 }
        }
        return levels
    }
}

/// Captures Apple Music's audio output through a Core Audio process tap and
/// publishes smoothed frequency-band levels (bass → treble) for the notch
/// equalizer. Capture requires the one-time System Audio Recording permission
/// (NSAudioCaptureUsageDescription); while capturing, macOS shows its
/// recording indicator in the menu bar.
///
/// Everything fails soft: if Music isn't running, any Core Audio step errors,
/// or the permission is denied (the tap then delivers pure silence),
/// `isCapturing` drops to false and the UI falls back to the procedural
/// visualizer animation.
@MainActor
final class AudioSpectrumAnalyzer: ObservableObject {
    nonisolated static let bandCount = 16

    @Published private(set) var data = SpectrumData.empty
    @Published private(set) var isCapturing = false

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var processor: SpectrumProcessor?
    private let dspQueue = DispatchQueue(label: "com.rutav.Glint.spectrum", qos: .userInteractive)
    /// Distinguishes silence-because-denied from a stop that already happened.
    private var session = 0
    private var startRetryWorkItem: DispatchWorkItem?

    func start(bundleID: String, retryCount: Int = 0) {
        guard ioProcID == nil else { return }
        
        startRetryWorkItem?.cancel()
        
        // Ensure the system prompts the user for Screen/Audio Recording permission,
        // which is required for CoreAudio process taps.
        _ = CGRequestScreenCaptureAccess()

        guard
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first?.processIdentifier,
            let processObject = Self.translate(pid: pid)
        else {
            if retryCount < 5 {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.start(bundleID: bundleID, retryCount: retryCount + 1)
                }
                self.startRetryWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            }
            return
        }

        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [processObject])
        tapDescription.name = "Glint Equalizer Tap"
        tapDescription.isPrivate = true
        tapDescription.muteBehavior = .unmuted

        var tapID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(tapDescription, &tapID) == noErr else { return }
        self.tapID = tapID

        // A tap can only be read through an aggregate device that includes it;
        // anchoring the aggregate on the default output keeps clocking sane.
        guard let outputUID = Self.defaultOutputDeviceUID() else {
            teardown()
            return
        }
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Glint Equalizer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
            ]],
        ]
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID) == noErr else {
            teardown()
            return
        }
        self.aggregateID = aggregateID

        let processor = SpectrumProcessor(
            sampleRate: Self.tapSampleRate(of: tapID) ?? 48_000
        ) { [weak self] data in
            DispatchQueue.main.async {
                guard let self, self.isCapturing else { return }
                self.data = data
            }
        }
        self.processor = processor

        var ioProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, dspQueue) { _, inputData, _, _, _ in
            processor.process(bufferList: inputData)
        }
        guard status == noErr, let ioProcID, AudioDeviceStart(aggregateID, ioProcID) == noErr else {
            teardown()
            return
        }
        self.ioProcID = ioProcID
        isCapturing = true
        scheduleDenialCheck()
    }

    func stop() {
        startRetryWorkItem?.cancel()
        teardown()
        isCapturing = false
        data = .empty
    }

    deinit {
        // Best-effort release of the tap if the owning view vanished without
        // onDisappear (properties are safe to touch from deinit here).
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        if aggregateID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
        }
    }

    private func teardown() {
        session += 1
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        processor = nil
    }

    /// A denied permission doesn't error — the tap just delivers silence.
    /// If nothing audible has arrived a few seconds into playback, treat the
    /// capture as unavailable so the UI falls back to the animated bars.
    private func scheduleDenialCheck() {
        let session = session
        let processor = processor
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.session == session, let processor else { return }
            self.dspQueue.async {
                let heard = processor.everHeardAudio
                DispatchQueue.main.async {
                    guard self.session == session, !heard else { return }
                    self.stop()
                }
            }
        }
    }

    // MARK: - Core Audio lookups

    private static func translate(pid: pid_t) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &pid) { pidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<pid_t>.size), pidPointer,
                &size, &object
            )
        }
        guard status == noErr, object != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return object
    }

    private static func defaultOutputDeviceUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        ) == noErr else { return nil }

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid) == noErr,
              let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    private static func tapSampleRate(of tapID: AudioObjectID) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format) == noErr,
              format.mSampleRate > 0
        else { return nil }
        return Float(format.mSampleRate)
    }
}

/// FFT and band mapping. Confined to the analyzer's DSP queue — the IO block
/// and `everHeardAudio` reads both run there.
private final class SpectrumProcessor {
    private static let fftSize = 1024
    private static let hopSize = 512
    private static let halfSize = fftSize / 2
    private static let bandEdges: [Float] = {
        let count = 16
        let minFreq: Float = 30
        let maxFreq: Float = 16_000
        return (0...count).map { i in
            minFreq * pow(maxFreq / minFreq, Float(i) / Float(count))
        }
    }()

    private(set) var everHeardAudio = false

    private let sampleRate: Float
    private let onLevels: (SpectrumData) -> Void
    private let dftSetup: vDSP_DFT_Setup?
    private let hannWindow: [Float]

    private var pendingSamples: [Float] = []
    // Fixed buffers with stable addresses — DSPSplitComplex holds raw
    // pointers, so Swift arrays (inout temporaries) are not safe here.
    private let windowed = UnsafeMutablePointer<Float>.allocate(capacity: fftSize)
    private let splitReal = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
    private let splitImag = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
    private let outputReal = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
    private let outputImag = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
    private let magnitudes = UnsafeMutablePointer<Float>.allocate(capacity: halfSize)

    private var smoothed = [Float](repeating: 0, count: AudioSpectrumAnalyzer.bandCount)
    private var lastBass: Float = 0
    /// Slow-decaying loudest-band reference so levels auto-calibrate to the
    /// tap's absolute scale instead of hardcoding gain.
    private var peakDB: Float = -12
    private var lastEmit = Date.distantPast

    init(sampleRate: Float, onLevels: @escaping (SpectrumData) -> Void) {
        self.sampleRate = sampleRate
        self.onLevels = onLevels
        dftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(Self.fftSize), .FORWARD)
        var window = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        hannWindow = window
    }

    deinit {
        if let dftSetup {
            vDSP_DFT_DestroySetup(dftSetup)
        }
        windowed.deallocate()
        splitReal.deallocate()
        splitImag.deallocate()
        outputReal.deallocate()
        outputImag.deallocate()
        magnitudes.deallocate()
    }

    func process(bufferList: UnsafePointer<AudioBufferList>) {
        guard dftSetup != nil else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: bufferList)
        )
        guard
            let buffer = buffers.first(where: { $0.mData != nil }),
            let data = buffer.mData
        else { return }

        let channels = max(Int(buffer.mNumberChannels), 1)
        let values = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
        let frames = values / channels
        guard frames > 0 else { return }
        let samples = data.assumingMemoryBound(to: Float32.self)

        pendingSamples.reserveCapacity(pendingSamples.count + frames)
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += samples[frame * channels + channel]
            }
            pendingSamples.append(sum / Float(channels))
        }

        while pendingSamples.count >= Self.fftSize {
            analyze(Array(pendingSamples.prefix(Self.fftSize)))
            pendingSamples.removeFirst(Self.hopSize)
        }
        // Playback hiccups shouldn't let the backlog grow without bound.
        if pendingSamples.count > Self.fftSize * 8 {
            pendingSamples.removeFirst(pendingSamples.count - Self.fftSize)
        }
    }

    private func analyze(_ samples: [Float]) {
        guard let dftSetup else { return }

        var peakSample: Float = 0
        vDSP_maxmgv(samples, 1, &peakSample, vDSP_Length(Self.fftSize))
        if peakSample > 0.001 {
            everHeardAudio = true
        }

        vDSP_vmul(samples, 1, hannWindow, 1, windowed, 1, vDSP_Length(Self.fftSize))
        windowed.withMemoryRebound(to: DSPComplex.self, capacity: Self.halfSize) { complexSamples in
            var split = DSPSplitComplex(realp: splitReal, imagp: splitImag)
            vDSP_ctoz(complexSamples, 2, &split, 1, vDSP_Length(Self.halfSize))
        }
        vDSP_DFT_Execute(dftSetup, splitReal, splitImag, outputReal, outputImag)
        outputImag[0] = 0 // drop the packed Nyquist bin out of the DC slot
        var split = DSPSplitComplex(realp: outputReal, imagp: outputImag)
        vDSP_zvmags(&split, 1, magnitudes, 1, vDSP_Length(Self.halfSize))

        // Average magnitude-squared per band, in dB.
        let binWidth = sampleRate / Float(Self.fftSize)
        var bandDB = [Float](repeating: -80, count: AudioSpectrumAnalyzer.bandCount)
        for band in 0..<AudioSpectrumAnalyzer.bandCount {
            let low = max(Int(Self.bandEdges[band] / binWidth), 1)
            let highRaw = Int(Self.bandEdges[band + 1] / binWidth)
            let high = min(max(low, highRaw), Self.halfSize - 1)
            guard high >= low else { continue }
            var mean: Float = 0
            vDSP_meanv(magnitudes + low, 1, &mean, vDSP_Length(high - low + 1))
            bandDB[band] = 10 * log10(mean + .leastNormalMagnitude)
            // Music energy falls off with frequency; a gentle tilt keeps the
            // treble bars visibly dancing instead of pinned near zero.
            bandDB[band] += Float(band) * 1.5
        }

        // Auto-calibrating normalization: the loudest band heard recently
        // sits near the top of the bars; ~1.5 dB/s decay tracks volume drops.
        if let maxDB = bandDB.max() {
            peakDB = max(maxDB, peakDB - 0.02)
        }
        let range: Float = 42
        for band in 0..<AudioSpectrumAnalyzer.bandCount {
            let level = min(max((bandDB[band] - (peakDB - range)) / range, 0), 1)
            // Fast attack so beats punch, slower release so bars fall gently.
            let factor: Float = level > smoothed[band] ? 0.65 : 0.08
            smoothed[band] += (level - smoothed[band]) * factor
        }

        let bass = (smoothed[0] + smoothed[1] + smoothed[2] + smoothed[3]) / 4.0
        let mid = (smoothed[4] + smoothed[5] + smoothed[6] + smoothed[7] + smoothed[8] + smoothed[9]) / 6.0
        let treble = (smoothed[10] + smoothed[11] + smoothed[12] + smoothed[13] + smoothed[14] + smoothed[15]) / 6.0
        
        let impulse = max(0, bass - lastBass)
        lastBass = bass

        let now = Date()
        if now.timeIntervalSince(lastEmit) >= 1.0 / 86.0 {
            lastEmit = now
            onLevels(SpectrumData(levels: smoothed, bassEnergy: bass, midEnergy: mid, trebleEnergy: treble, beatImpulse: impulse))
        }
    }
}
