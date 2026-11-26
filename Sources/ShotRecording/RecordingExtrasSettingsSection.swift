import AppKit
import ShotCore
import SwiftUI

/// Settings > Recording section for the webcam bubble and keystroke display.
/// Embed it inside a `Form` (grouped style).
public struct RecordingExtrasSettingsSection: View {
    @State private var prefs = RecordingExtrasPreferences.load()
    @State private var isTrusted = RecordingPermissions.isAccessibilityTrusted
    @State private var isCameraDenied = RecordingPermissions.isCameraDenied

    public init() {}

    public var body: some View {
        Group {
            webcamSection
            keystrokeSection
        }
        .onChange(of: prefs) { _, newValue in newValue.save() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onAppear(perform: refreshPermissions)
    }

    private var webcamSection: some View {
        Section {
            Toggle(String(localized: "Show webcam", bundle: .module), isOn: $prefs.showWebcam)
            Picker(String(localized: "Shape", bundle: .module), selection: $prefs.webcamShape) {
                ForEach(WebcamShape.allCases) { Text($0.title).tag($0) }
            }
            .disabled(!prefs.showWebcam)
            Picker(String(localized: "Size", bundle: .module), selection: $prefs.webcamSize) {
                ForEach(WebcamSize.allCases) { Text($0.title).tag($0) }
            }
            .disabled(!prefs.showWebcam)
        } header: {
            Text("Webcam", bundle: .module)
        } footer: {
            Text(webcamFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var keystrokeSection: some View {
        Section {
            Toggle(String(localized: "Show keystrokes", bundle: .module), isOn: $prefs.showKeystrokes)
                .disabled(!isTrusted)
            Toggle(String(localized: "Only shortcuts (hide typed text)", bundle: .module), isOn: $prefs.keystrokesShortcutsOnly)
                .disabled(!isTrusted || !prefs.showKeystrokes)
            if !isTrusted {
                LabeledContent(String(localized: "Accessibility access", bundle: .module)) {
                    HStack(spacing: DS.Space.s) {
                        Button(String(localized: "Allow…", bundle: .module)) {
                            RecordingPermissions.promptForAccessibility()
                        }
                        Button(String(localized: "Open System Settings", bundle: .module)) {
                            RecordingPermissions.openAccessibilitySettings()
                        }
                    }
                }
            }
        } header: {
            Text("Keystrokes", bundle: .module)
        } footer: {
            Text(RecordingPermissions.accessibilityHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var webcamFooter: String {
        if isCameraDenied {
            return String(localized: "Camera access is denied. Allow it in System Settings > Privacy & Security > Camera.", bundle: .module)
        }
        return String(
            localized: "The webcam bubble is recorded with the screen. Drag it to move; right-click it for size and shape.",
            bundle: .module
        )
    }

    private func refreshPermissions() {
        isTrusted = RecordingPermissions.isAccessibilityTrusted
        isCameraDenied = RecordingPermissions.isCameraDenied
    }
}

extension WebcamShape {
    var title: String {
        switch self {
        case .circle: return String(localized: "Circle", bundle: .module)
        case .roundedRect: return String(localized: "Rounded Rectangle", bundle: .module)
        }
    }
}

extension WebcamSize {
    var title: String {
        switch self {
        case .small: return String(localized: "Small", bundle: .module)
        case .medium: return String(localized: "Medium", bundle: .module)
        case .large: return String(localized: "Large", bundle: .module)
        }
    }
}
