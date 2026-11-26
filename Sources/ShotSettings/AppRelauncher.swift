import AppKit
import ShotCore

/// Relaunches the running app (used to apply a language change).
@MainActor
enum AppRelauncher {
    private static let launchDelay: Duration = .milliseconds(500)

    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundlePath]
        Task {
            try? await Task.sleep(for: launchDelay)
            do {
                try process.run()
                Log.settings.info("Relaunching app to apply language change")
                NSApp.terminate(nil)
            } catch {
                Log.settings.error("Relaunch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
