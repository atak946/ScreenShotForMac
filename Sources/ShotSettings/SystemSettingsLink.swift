import AppKit
import ShotCore

/// Deep links into System Settings panes.
enum SystemSettingsLink: String {
    case keyboardShortcuts = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    case screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case microphone = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    case privacy = "x-apple.systempreferences:com.apple.preference.security?Privacy"

    @MainActor
    func open() {
        guard let url = URL(string: rawValue) else {
            Log.settings.error("Invalid System Settings URL: \(rawValue, privacy: .public)")
            return
        }
        if !NSWorkspace.shared.open(url) {
            Log.settings.error("Failed to open System Settings URL: \(rawValue, privacy: .public)")
        }
    }
}
