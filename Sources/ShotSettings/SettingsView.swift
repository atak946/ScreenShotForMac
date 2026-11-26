import ShotCore
import SwiftUI

/// SwiftUI-only settings root (kept for compatibility, e.g. a `Settings` scene).
/// The app uses `SettingsWindowController`, which shows the same panes in a toolbar window.
public struct SettingsView: View {
    private let context: SettingsContext

    public static let preferredWidth: CGFloat = SettingsPane.width

    public init(
        settings: AppSettings = .shared,
        chooseSaveFolder: @escaping @MainActor () -> Void,
        saveFolderPath: @escaping @MainActor () -> String,
        clearHistory: @escaping @MainActor () -> Void = {},
        openHistoryFolder: @escaping @MainActor () -> Void = {}
    ) {
        context = SettingsContext(
            settings: settings,
            chooseSaveFolder: chooseSaveFolder,
            saveFolderPath: saveFolderPath,
            clearHistory: clearHistory,
            openHistoryFolder: openHistoryFolder
        )
    }

    public var body: some View {
        TabView {
            ForEach(SettingsPane.allCases) { pane in
                pane.makeContent(context)
                    .tabItem { Label(pane.title, systemImage: pane.symbol) }
            }
        }
        .frame(width: Self.preferredWidth)
        .frame(minHeight: 420, maxHeight: 720)
    }
}
