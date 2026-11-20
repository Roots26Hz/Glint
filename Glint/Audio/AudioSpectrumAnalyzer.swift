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
    
    /// The bands resampled to `count` bars spanning the whole spectrum:
    /// fewer bars average neighbouring bands, more bars repeat them. Always
    /// returns exactly `count` values, so renderers can index any bar count.
    func levels(for count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !levels.isEmpty else { return [Float](repeating: 0, count: count) }
        if count == levels.count { return levels }
        return (0..<count).map { bar in
            let start = bar * levels.count / count
            let end = max(start + 1, (bar + 1) * levels.count / count)
            let slice = levels[start..<min(end, levels.count)]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }
}

/// Timeouts for the audio-reactive visualizer, kept in one place.
enum VisualizerTiming {
    /// How long a playback request may take to produce audible audio before
    /// the notch switches to the animated visualizer.
    static let playbackStartTimeout: TimeInterval = 4
    /// How long a playing track may go silent (buffering, a stalled stream)
    /// before the notch switches to the animated visualizer.
    static let audioStallTimeout: TimeInterval = 4
}

/// Captures Apple Music's audio output through a Core Audio process tap and
/// publishes smoothed frequency-band levels (bass → treble) for the notch
/// equalizer. Capture requires the one-time System Audio Recording permission
/// (NSAudioCaptureUsageDescription); while capturing, macOS shows its
/// recording indicator in the menu bar.
///
/// Everything fails soft: if Music isn't running or any Core Audio step
/// errors, `isCapturing` stays false and the UI shows the procedural
/// visualizer animation.
///
/// A running tap doesn't mean audio is flowing: a stream can still be
/// buffering, playback can be stuck, or the permission can be denied (the tap
/// then delivers pure silence). `source` tracks that, and a watchdog switches
/// the bars to the animated visualizer when no audio arrives within
/// `VisualizerTiming`'s limits, then back once it does. The tap keeps running
/// meanwhile, so late audio is picked up without restarting anything.
@MainActor
final class AudioSpectrumAnalyzer: ObservableObject {
    nonisolated static let bandCount = 16

    enum Source: Equatable {
        /// Playback was requested; waiting for the first audible audio.
        case waiting
        /// Audio is flowing and drives the bars.
        case live
        /// No audio within the timeout; the animated visualizer stands in
        /// until audio arrives.
        case fallback
    }

    @Published private(set) var data = SpectrumData.empty
    @Published private(set) var isCapturing = false
    @Published private(set) var source = Source.waiting

    /// Whether the bars should follow the captured audio rather than the
    /// animated visualizer.
    var isAudioReactive: Bool { isCapturing && source != .fallback }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var processor: SpectrumProcessor?
    private let dspQueue = DispatchQueue(label: "com.rutav.Glint.spectrum", qos: .userInteractive)
    /// Bumped on every teardown, so callbacks from an earlier tap are ignored.
    private var session = 0
    private var startRetryWorkItem: DispatchWorkItem?
    /// The single playback watchdog; runs only while the tap does.
    private var watchdog: Timer?
    /// System uptime when the current playback request began.
    private var waitingSince: TimeInterval = 0
    /// System uptime of the last audible audio from the tap.
    private var lastAudible: TimeInterval = 0

    func start(bundleID: String, retryCount: Int = 0) {
        guard ioProcID == nil else { return }
        
        startRetryWorkItem?.cancel()

        // No permission request here: starting the tap's aggregate device
        // below makes macOS ask for System Audio Recording (the
        // NSAudioCaptureUsageDescription prompt) the first time. Process taps
        // don't need Screen Recording, so never request it.

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

        let session = session
        let processor = SpectrumProcessor(
            sampleRate: Self.tapSampleRate(of: tapID) ?? 48_000
        ) { [weak self] data, audible in
            DispatchQueue.main.async {
                guard let self, self.isCapturing, self.session == session else { return }
                self.data = data
                if audible { self.noteAudible() }
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
        lastAudible = 0
        armWatchdog()
    }

    func stop() {
        startRetryWorkItem?.cancel()
        teardown()
        isCapturing = false
        data = .empty
    }

    /// A new play, skip or track change: give the new audio a fresh start-up
    /// window before falling back to the animated visualizer. Before the tap
    /// is running this does nothing; `start` arms the watchdog itself.
    func playbackRequested() {
        guard isCapturing else { return }
        armWatchdog()
    }

    deinit {
        // Best-effort release of the tap if the owning view vanished without
        // onDisappear (properties are safe to touch from deinit here).
        watchdog?.invalidate()
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
        watchdog?.invalidate()
        watchdog = nil
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

    // MARK: - Playback watchdog

    /// Starts a playback start-up window. Audio that is already flowing (a
    /// track change mid-stream) stays live; the stall check covers it.
    private func armWatchdog() {
        let now = ProcessInfo.processInfo.systemUptime
        waitingSince = now
        if now - lastAudible > 0.5 {
            setSource(.waiting)
        }
        guard watchdog == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkWatchdog() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func checkWatchdog() {
        let now = ProcessInfo.processInfo.systemUptime
        switch source {
        case .waiting where now - waitingSince >= VisualizerTiming.playbackStartTimeout:
            setSource(.fallback)
        case .live where now - lastAudible >= VisualizerTiming.audioStallTimeout:
            setSource(.fallback)
        default:
            break
        }
    }

    private func noteAudible() {
        lastAudible = ProcessInfo.processInfo.systemUptime
        if source != .live {
            setSource(.live)
        }
    }

    private func setSource(_ newSource: Source) {
        guard source != newSource else { return }
        NSLog("Glint visualizer: \(source) → \(newSource)")
        source = newSource
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

/// FFT and band mapping. Confined to the analyzer's DSP queue, where the IO
/// block runs.
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

    /// Peak sample level above which a frame counts as actual audio rather
    /// than the silence a stalled stream or a denied permission delivers.
    private static let audibleThreshold: Float = 0.001

    /// Whether any frame since the last emission was audible.
    private var heardSinceEmit = false

    private let sampleRate: Float
    /// Called with the smoothed levels and whether audio was heard.
    private let onLevels: (SpectrumData, Bool) -> Void
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

    init(sampleRate: Float, onLevels: @escaping (SpectrumData, Bool) -> Void) {
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
        if peakSample > Self.audibleThreshold {
            heardSinceEmit = true
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
            onLevels(SpectrumData(levels: smoothed, bassEnergy: bass, midEnergy: mid, trebleEnergy: treble, beatImpulse: impulse), heardSinceEmit)
            heardSinceEmit = false
        }
    }
}
