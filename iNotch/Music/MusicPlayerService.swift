import AppKit
import Combine
import SwiftUI

/// Observes and controls Apple Music.
///
/// State changes arrive instantly via the `com.apple.Music.playerInfo`
/// distributed notification (no polling). Track details, artwork, and playback
/// controls go through AppleScript, serialized on a background queue so the
/// UI never blocks. Except for `playPause` — which deliberately launches
/// Music.app so playback can be resumed straight from the notch — we only
/// talk to Music when it is already running.
@MainActor
final class MusicPlayerService: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var duration: Double = 0
    @Published private(set) var position: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkColor: Color = ArtworkColorExtractor.fallback

    private let scriptQueue = DispatchQueue(label: "com.rutav.iNotch.applescript")
    private var positionTimer: Timer?
    private var artworkKey = ""

    private static let musicBundleID = "com.apple.Music"
    /// Unit separator — safe delimiter for AppleScript string results.
    private static let sep = "\u{1F}"

    init() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playerInfoChanged(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        if isMusicRunning {
            refreshFullState()
        }
    }

    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).isEmpty
    }

    // MARK: - Notifications

    @objc private func playerInfoChanged(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let state = (info["Player State"] as? String) ?? "Stopped"

        if state == "Playing" || state == "Paused" {
            isPlaying = state == "Playing"
            title = (info["Name"] as? String) ?? ""
            artist = (info["Artist"] as? String) ?? ""
            album = (info["Album"] as? String) ?? ""
            if let totalTimeMS = info["Total Time"] as? Double {
                duration = totalTimeMS / 1000
            } else if let totalTimeMS = info["Total Time"] as? Int {
                duration = Double(totalTimeMS) / 1000
            }
            refreshPosition()
            refreshArtworkIfNeeded()
        } else {
            // Stopped, or Music quit.
            isPlaying = false
            title = ""
            artist = ""
            album = ""
            duration = 0
            position = 0
            artwork = nil
            artworkKey = ""
            artworkColor = ArtworkColorExtractor.fallback
        }
    }

    // MARK: - Queries

    /// Full state pull, used once at launch (Music may already be playing).
    private func refreshFullState() {
        let script = """
        tell application "Music"
            set sepChar to character id 31
            set st to (player state as text)
            if st is not "playing" and st is not "paused" then return st
            set t to current track
            return st & sepChar & (name of t) & sepChar & (artist of t) & sepChar & (album of t) & sepChar & (player position as text) & sepChar & ((duration of t) as text)
        end tell
        """
        runScript(script) { [weak self] descriptor in
            guard let self, let raw = descriptor?.stringValue else { return }
            let parts = raw.components(separatedBy: Self.sep)
            guard parts.count == 6 else { return }
            self.isPlaying = parts[0].lowercased() == "playing"
            self.title = parts[1]
            self.artist = parts[2]
            self.album = parts[3]
            self.position = Self.parseNumber(parts[4])
            self.duration = Self.parseNumber(parts[5])
            self.refreshArtworkIfNeeded()
        }
    }

    private func refreshPosition() {
        guard isMusicRunning else { return }
        let script = """
        tell application "Music"
            if player state is stopped then return "0"
            return (player position as text)
        end tell
        """
        runScript(script) { [weak self] descriptor in
            guard let self, let raw = descriptor?.stringValue else { return }
            self.position = Self.parseNumber(raw)
        }
    }

    private func refreshArtworkIfNeeded() {
        let key = "\(title)|\(artist)|\(album)"
        guard key != artworkKey, isMusicRunning else { return }
        artworkKey = key

        let script = """
        tell application "Music"
            if player state is stopped then return ""
            try
                return raw data of artwork 1 of current track
            on error
                return ""
            end try
        end tell
        """
        runScript(script) { [weak self] descriptor in
            guard let self, let descriptor else { return }
            let data = descriptor.data
            let image = data.isEmpty ? nil : NSImage(data: data)
            self.artwork = image
            self.updateArtworkColor(from: image)
        }
    }

    private func updateArtworkColor(from image: NSImage?) {
        guard let image else {
            artworkColor = ArtworkColorExtractor.fallback
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let color = ArtworkColorExtractor.dominantColor(from: image)
            DispatchQueue.main.async {
                self?.artworkColor = color
            }
        }
    }

    // MARK: - Controls

    func playPause() {
        if isMusicRunning {
            runCommand("playpause")
        } else {
            // Auto-launches Music.app and resumes the last playback context.
            // The playerInfo notification self-heals state once playback
            // starts; the explicit refresh is a belt-and-braces sync.
            runScript("tell application \"Music\" to play") { [weak self] _ in
                self?.refreshFullState()
            }
        }
    }
    func nextTrack() { runCommand("next track") }
    func previousTrack() { runCommand("back track") }

    func seek(to seconds: Double) {
        position = seconds
        runCommand("set player position to \(Int(seconds))")
    }

    private func runCommand(_ command: String) {
        guard isMusicRunning else { return }
        runScript("tell application \"Music\" to \(command)") { _ in }
    }

    // MARK: - Expanded-state position ticker

    /// While the expanded player is visible, re-sync the progress bar once a second.
    func setExpanded(_ expanded: Bool) {
        positionTimer?.invalidate()
        positionTimer = nil
        guard expanded else { return }
        refreshPosition()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPosition()
            }
        }
    }

    // MARK: - AppleScript plumbing

    /// Runs a script on the serial background queue, delivers the result on main.
    private func runScript(_ source: String, completion: @escaping (NSAppleEventDescriptor?) -> Void) {
        scriptQueue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                NSLog("iNotch AppleScript error: \(error)")
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// AppleScript renders reals with the user's locale decimal separator.
    private static func parseNumber(_ raw: String) -> Double {
        Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
