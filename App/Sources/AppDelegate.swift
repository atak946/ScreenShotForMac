import AppKit
import ShotCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        statusMenu = StatusMenuController(coordinator: coordinator)
        coordinator.start()
        Log.app.info("Launched")
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { coordinator?.handle($0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.perform(.openSettings)
        return false
    }
}
