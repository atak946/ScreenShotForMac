import SwiftUI

/// Built-in pane identifiers, usable as anchors for `SettingsExtraPane` and for `show(pane:)`.
public enum SettingsPaneID {
    public static let general = SettingsPane.general.rawValue
    public static let shortcuts = SettingsPane.shortcuts.rawValue
    public static let output = SettingsPane.output.rawValue
    public static let recording = SettingsPane.recording.rawValue
    public static let tools = SettingsPane.tools.rawValue
    public static let history = SettingsPane.history.rawValue
    public static let permissions = SettingsPane.permissions.rawValue
    public static let about = SettingsPane.about.rawValue
}

/// A pane contributed by another module (e.g. Upload, Workflows) without ShotSettings depending on it.
public struct SettingsExtraPane {
    /// Where the pane goes in the sidebar.
    public enum Position: Sendable, Equatable {
        /// Before the built-in pane with this id (see `SettingsPaneID`), in that pane's group.
        case before(String)
        /// After every built-in pane.
        case end
    }

    public let id: String
    public let title: String
    public let symbol: String
    /// Background of the sidebar icon tile.
    public let tint: Color
    public let content: AnyView
    public let position: Position

    public init(
        id: String,
        title: String,
        symbol: String,
        tint: Color = .accentColor,
        position: Position = .end,
        content: AnyView
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.position = position
        self.content = content
    }
}

/// One sidebar row: a built-in pane or an injected one.
struct SettingsEntry: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    /// Sidebar group index (0 = basics, 1 = features, 2 = system).
    let group: Int
    let makeContent: @MainActor () -> AnyView

    @MainActor
    static func entries(context: SettingsContext, extras: [SettingsExtraPane]) -> [SettingsEntry] {
        var result = SettingsPane.allCases.map { pane in
            SettingsEntry(
                id: pane.rawValue, title: pane.title, symbol: pane.symbol, tint: pane.tint, group: pane.group
            ) { pane.makeContent(context) }
        }
        for extra in extras {
            let anchorIndex: Int? = if case let .before(anchor) = extra.position {
                result.firstIndex { $0.id == anchor }
            } else {
                nil
            }
            let group = anchorIndex.map { result[$0].group } ?? (result.last?.group ?? 0)
            let entry = SettingsEntry(
                id: extra.id, title: extra.title, symbol: extra.symbol, tint: extra.tint, group: group
            ) { extra.content }
            result.insert(entry, at: anchorIndex ?? result.endIndex)
        }
        return result
    }
}
