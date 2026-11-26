import ShotCore
import SwiftUI

struct HistorySettingsTab: View {
    @Bindable var settings: AppSettings
    let clearHistory: @MainActor () -> Void
    let openHistoryFolder: @MainActor () -> Void

    @State private var isConfirmingClear = false

    private static var baseRetentionOptions: [(days: Int, label: String)] {
        [
            (1, String(localized: "1 day", bundle: .module)),
            (7, String(localized: "7 days", bundle: .module)),
            (30, String(localized: "30 days", bundle: .module)),
            (90, String(localized: "90 days", bundle: .module)),
            (0, String(localized: "Forever", bundle: .module)),
        ]
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Keep a history of captures", bundle: .module), isOn: $settings.historyEnabled)
                Picker(String(localized: "Keep captures for", bundle: .module), selection: $settings.historyRetentionDays) {
                    ForEach(retentionOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!settings.historyEnabled)
            } header: {
                Text("History", bundle: .module)
            } footer: {
                SettingsFooter(text: String(localized: "History is stored locally on this Mac and is never uploaded.", bundle: .module))
            }
            Section {
                LabeledContent(String(localized: "Storage", bundle: .module)) {
                    HStack(spacing: DS.Space.s) {
                        Button(String(localized: "Open History Folder", bundle: .module)) { openHistoryFolder() }
                        Button(String(localized: "Clear History…", bundle: .module), role: .destructive) { isConfirmingClear = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(String(localized: "Clear all capture history?", bundle: .module), isPresented: $isConfirmingClear) {
            Button(String(localized: "Clear History", bundle: .module), role: .destructive) {
                clearHistory()
                Log.settings.info("History cleared from settings")
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("This permanently deletes every saved history item. This cannot be undone.", bundle: .module)
        }
    }

    private var retentionOptions: [(days: Int, label: String)] {
        let current = settings.historyRetentionDays
        let base = Self.baseRetentionOptions
        guard !base.contains(where: { $0.days == current }) else { return base }
        return base + [(current, String(localized: "\(current) days", bundle: .module))]
    }
}
