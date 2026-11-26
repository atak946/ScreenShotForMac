import ShotCore
import SwiftUI

/// Closures and model shared by every settings pane.
struct SettingsContext {
    let settings: AppSettings
    let chooseSaveFolder: @MainActor () -> Void
    let saveFolderPath: @MainActor () -> String
    let clearHistory: @MainActor () -> Void
    let openHistoryFolder: @MainActor () -> Void
    /// Extra sections appended to the Recording pane (e.g. webcam / keystrokes).
    var recordingExtras: AnyView?
}

/// The panes of the Settings window, in toolbar order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, shortcuts, output, recording, tools, history, permissions, about

    /// Preferred pane width (used by the SwiftUI-only `SettingsView`).
    static let width: CGFloat = 620

    private static let selectionKey = "settings.lastSelectedPane"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "General", bundle: .module)
        case .shortcuts: return String(localized: "Shortcuts", bundle: .module)
        case .output: return String(localized: "Output", bundle: .module)
        case .recording: return String(localized: "Recording", bundle: .module)
        case .tools: return String(localized: "Tools", bundle: .module)
        case .history: return String(localized: "History", bundle: .module)
        case .permissions: return String(localized: "Permissions", bundle: .module)
        case .about: return String(localized: "About", bundle: .module)
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .output: return "square.and.arrow.down"
        case .recording: return "record.circle"
        case .tools: return "wrench.and.screwdriver"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }

    /// Sidebar icon tile color (System Settings style).
    var tint: Color {
        switch self {
        case .general: return .gray
        case .shortcuts: return .indigo
        case .output: return .blue
        case .recording: return .red
        case .tools: return .orange
        case .history: return .teal
        case .permissions: return .green
        case .about: return .secondary
        }
    }

    /// Sidebar group: basics, features, system.
    var group: Int {
        switch self {
        case .general, .shortcuts, .output: return 0
        case .recording, .tools, .history: return 1
        case .permissions, .about: return 2
        }
    }

    @MainActor
    func makeContent(_ context: SettingsContext) -> AnyView {
        switch self {
        case .general:
            return AnyView(GeneralSettingsTab(settings: context.settings))
        case .shortcuts:
            return AnyView(ShortcutsSettingsTab())
        case .output:
            return AnyView(OutputSettingsTab(
                settings: context.settings,
                chooseSaveFolder: context.chooseSaveFolder,
                saveFolderPath: context.saveFolderPath
            ))
        case .recording:
            return AnyView(RecordingSettingsTab(settings: context.settings, extras: context.recordingExtras))
        case .tools:
            return AnyView(ToolsSettingsTab(settings: context.settings))
        case .history:
            return AnyView(HistorySettingsTab(
                settings: context.settings,
                clearHistory: context.clearHistory,
                openHistoryFolder: context.openHistoryFolder
            ))
        case .permissions:
            return AnyView(PermissionsSettingsTab())
        case .about:
            return AnyView(AboutSettingsTab())
        }
    }

    /// Identifier of the last selected pane (built-in or injected).
    static var lastSelectedID: String {
        get { UserDefaults.standard.string(forKey: selectionKey) ?? SettingsPane.general.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: selectionKey) }
    }
}
