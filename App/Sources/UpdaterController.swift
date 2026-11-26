import AppKit
import ShotCore
import Sparkle

/// Sparkle 2 auto-updates. The appcast and DMGs are published as GitHub Release assets
/// (see scripts/publish-release.sh); the feed URL and EdDSA public key live in Info.plist.
@MainActor
final class UpdaterController: NSObject, SPUStandardUserDriverDelegate {
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )

    func start() {
        _ = controller
        Log.app.info("Updater started (automatic checks: \(self.controller.updater.automaticallyChecksForUpdates))")
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    func checkForUpdates() {
        // Menu-bar apps must come to the front, otherwise Sparkle's window opens behind other apps.
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Lets Sparkle show gentle reminders for scheduled checks in a background (LSUIElement) app.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
