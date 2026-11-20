import AppKit
import Combine
import Sparkle

/// In-app updates through Sparkle and GitHub Releases.
///
/// The feed is the appcast.xml attached to the latest GitHub Release
/// (SUFeedURL in Info.plist). Sparkle installs an update only if its archive
/// carries a valid EdDSA signature for SUPublicEDKey and the new app is
/// code-signed by the same identity as this one, so nothing unverified is
/// ever installed. Network failures surface only on user-initiated checks;
/// checks run off the main thread and never touch playback.
@MainActor
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    @Published private(set) var canCheckForUpdates = false
    /// Newest version the last completed check found (this version when up
    /// to date); nil until a check has completed this session.
    @Published private(set) var latestVersion: String?
    @Published private(set) var lastCheckDate: Date?
    /// A scheduled check found this version and is waiting for the user
    /// (gentle reminder: Glint is a menu-bar app, so it never steals focus).
    @Published private(set) var pendingUpdateVersion: String?

    let currentVersion: String
    let currentBuild: String

    private var controller: SPUStandardUpdaterController!

    private override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        currentVersion = info["CFBundleShortVersionString"] as? String ?? "?"
        currentBuild = info["CFBundleVersion"] as? String ?? "?"
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: self
        )
        lastCheckDate = controller.updater.lastUpdateCheckDate
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    /// User-initiated check: Sparkle shows "up to date", the update with its
    /// release notes and an install button, or the error.
    func checkForUpdates() {
        // Bring the menu-bar app forward so Sparkle's window isn't hidden
        // behind the active app.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    /// Fills in "latest available" without any UI — only while automatic
    /// checks are on, so turning them off really means no background traffic.
    func refreshLatestVersionIfAllowed() {
        guard latestVersion == nil, automaticallyChecksForUpdates, canCheckForUpdates else { return }
        controller.updater.checkForUpdateInformation()
    }
}

extension UpdateController: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        latestVersion = item.displayVersionString
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        latestVersion = currentVersion
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        lastCheckDate = updater.lastUpdateCheckDate
    }
}

extension UpdateController: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated { pendingUpdateVersion = version }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { pendingUpdateVersion = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { pendingUpdateVersion = nil }
    }
}
