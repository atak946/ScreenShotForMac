import ShotCore
import SwiftUI

/// Language active in this process; changing the setting only takes effect after a relaunch.
@MainActor
private enum LaunchLanguage {
    static let value = AppSettings.shared.appLanguage
}

struct GeneralSettingsTab: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin()

    private static let baseAutoCloseOptions = [0, 3, 5, 10, 15, 30]
    private static let baseDelayOptions = [3, 5, 10]

    var body: some View {
        Form {
            startupSection
            afterCaptureSection
            captureSection
            editorSection
        }
        .formStyle(.grouped)
        .onAppear {
            _ = LaunchLanguage.value
            launchAtLogin.refresh()
        }
    }

    // MARK: Startup & language

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var startupSection: some View {
        Section {
            Toggle(String(localized: "Launch at login", bundle: .module), isOn: launchBinding)
            if launchAtLogin.requiresApproval {
                LabeledContent {
                    Button(String(localized: "Open Login Items…", bundle: .module)) { launchAtLogin.openLoginItemsSettings() }
                } label: {
                    Label(
                        String(localized: "Approval required in Login Items", bundle: .module),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }
            if let error = launchAtLogin.lastError {
                Label(error, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
            Picker(String(localized: "Language", bundle: .module), selection: $settings.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.menu)
            if settings.appLanguage != LaunchLanguage.value {
                LabeledContent(String(localized: "Restart the app to apply.", bundle: .module)) {
                    Button(String(localized: "Restart Now", bundle: .module)) { AppRelauncher.relaunch() }
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Startup", bundle: .module)
        }
    }

    // MARK: After capture

    private var afterCaptureSection: some View {
        Section {
            Picker(String(localized: "Action", bundle: .module), selection: $settings.afterCapture) {
                ForEach(AfterCaptureBehavior.allCases) { behavior in
                    Text(behavior.label).tag(behavior)
                }
            }
            .pickerStyle(.menu)
            Toggle(String(localized: "Also copy to clipboard", bundle: .module), isOn: $settings.alsoCopyToClipboard)
                .disabled(settings.afterCapture == .copyToClipboard)
            Picker(String(localized: "Close Quick Access", bundle: .module), selection: autoCloseBinding) {
                ForEach(autoCloseOptions, id: \.self) { seconds in
                    Text(autoCloseLabel(seconds)).tag(seconds)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("After Capture", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "Choose what happens as soon as a screenshot is taken.", bundle: .module))
        }
    }

    private var autoCloseBinding: Binding<Int> {
        Binding(
            get: { Int(settings.quickAccessAutoCloseSeconds.rounded()) },
            set: { settings.quickAccessAutoCloseSeconds = Double($0) }
        )
    }

    private var autoCloseOptions: [Int] {
        RecordingSettingsTab.options(Self.baseAutoCloseOptions, current: autoCloseBinding.wrappedValue)
    }

    private func autoCloseLabel(_ seconds: Int) -> String {
        seconds == 0
            ? String(localized: "Never", bundle: .module)
            : String(localized: "After \(seconds) seconds", bundle: .module)
    }

    // MARK: Capture & editor

    private var captureSection: some View {
        Section {
            Toggle(String(localized: "Show magnifier while selecting", bundle: .module), isOn: $settings.showMagnifier)
            Toggle(String(localized: "Include window shadow", bundle: .module), isOn: $settings.captureWindowShadow)
            Picker(String(localized: "Capture timer", bundle: .module), selection: $settings.captureDelaySeconds) {
                ForEach(RecordingSettingsTab.options(Self.baseDelayOptions, current: settings.captureDelaySeconds), id: \.self) {
                    Text("\($0) seconds", bundle: .module).tag($0)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Capture", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "The timer is used by “\(AppCommand.captureDelayed.title)”.", bundle: .module))
        }
    }

    private var editorSection: some View {
        Section {
            Toggle(String(localized: "Close editor after saving", bundle: .module), isOn: $settings.editorCloseAfterSave)
        } header: {
            Text("Editor", bundle: .module)
        }
    }
}
