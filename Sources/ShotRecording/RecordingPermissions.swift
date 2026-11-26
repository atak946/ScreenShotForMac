import AppKit
import ApplicationServices
import AVFoundation

/// Permission checks for the optional recording extras (webcam, keystrokes).
enum RecordingPermissions {
    /// Global key monitors only deliver key events to Accessibility-trusted apps.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system Accessibility prompt (adds the app to the list in System Settings).
    static func promptForAccessibility() {
        // Literal value of `kAXTrustedCheckOptionPrompt`; the global is not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings > Privacy & Security > Accessibility.
    @MainActor
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Requests camera access only when it was never asked before.
    static func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    static var isCameraDenied: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }

    static var accessibilityHint: String {
        String(
            localized: "Keystroke display needs Accessibility access (System Settings > Privacy & Security > Accessibility).",
            bundle: .module
        )
    }
}
