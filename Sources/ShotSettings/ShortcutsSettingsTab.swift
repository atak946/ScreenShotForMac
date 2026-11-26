import KeyboardShortcuts
import ShotCore
import SwiftUI

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            ForEach(HotkeyGroup.allCases) { group in
                Section {
                    ForEach(group.commands) { command in
                        recorder(for: command, color: group.tint)
                    }
                } header: {
                    Text(group.title)
                }
            }
            Section {
                LabeledContent(String(localized: "Shortcuts work from any app. Leave one empty to disable it.", bundle: .module)) {
                    Button(String(localized: "Restore Defaults", bundle: .module)) {
                        KeyboardShortcuts.reset(HotkeyRegistry.allNames)
                        Log.settings.info("Hotkeys restored to defaults")
                    }
                }
                .foregroundStyle(.secondary)
            }
            systemShortcutsSection
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func recorder(for command: AppCommand, color: Color) -> some View {
        if let name = HotkeyRegistry.name(for: command) {
            KeyboardShortcuts.Recorder(for: name) {
                SettingsRowLabel(title: command.title, symbol: command.systemImage, color: color)
            }
        }
    }

    private var systemShortcutsSection: some View {
        Section {
            LabeledContent {
                Button(String(localized: "Open Keyboard Shortcuts…", bundle: .module)) { SystemSettingsLink.keyboardShortcuts.open() }
            } label: {
                SettingsRowLabel(
                    title: String(localized: "Replace the built-in screenshot shortcuts", bundle: .module),
                    symbol: "command",
                    color: .gray,
                    subtitle: String(localized: """
                    To use ⌘⇧3, ⌘⇧4 or ⌘⇧5 here, first turn them off in System Settings › Keyboard › \
                    Keyboard Shortcuts › Screenshots, then record them above.
                    """, bundle: .module)
                )
            }
        } header: {
            Text("macOS Screenshot Shortcuts", bundle: .module)
        }
    }
}

extension HotkeyGroup {
    /// Icon tile color for the group's rows.
    var tint: Color {
        switch self {
        case .capture: return .blue
        case .recording: return .red
        case .tools: return .orange
        case .app: return .purple
        }
    }
}
