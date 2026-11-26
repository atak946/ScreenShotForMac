import Observation
import ServiceManagement
import ShotCore

/// Thin observable wrapper around `SMAppService.mainApp`.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    private(set) var lastError: String?

    var isEnabled: Bool { status == .enabled }
    var requiresApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.settings.info("Launch at login set to \(enabled)")
        } catch {
            lastError = error.localizedDescription
            Log.settings.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
