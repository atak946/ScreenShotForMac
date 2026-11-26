import ShotCore
import SwiftUI

/// Selected pane, persisted across launches.
@MainActor
@Observable
final class SettingsNavigationModel {
    let entries: [SettingsEntry]
    /// Called with the selected pane's title (used for the window title).
    @ObservationIgnored var onTitleChange: (@MainActor (String) -> Void)?

    var selection: String? {
        didSet {
            guard let selection, selection != oldValue else { return }
            if let title = selectedEntry?.title { onTitleChange?(title) }
            SettingsPane.lastSelectedID = selection
            Log.settings.debug("Settings pane selected: \(selection, privacy: .public)")
        }
    }

    init(entries: [SettingsEntry]) {
        self.entries = entries
        let stored = SettingsPane.lastSelectedID
        selection = entries.contains { $0.id == stored } ? stored : entries.first?.id
    }

    var selectedEntry: SettingsEntry? {
        entries.first { $0.id == selection } ?? entries.first
    }

    /// Entries split into sidebar groups, in order.
    var groups: [[SettingsEntry]] {
        Dictionary(grouping: entries, by: \.group)
            .sorted { $0.key < $1.key }
            .map(\.value)
    }

    func select(_ id: String) {
        guard entries.contains(where: { $0.id == id }) else { return }
        selection = id
    }
}

/// System Settings-style layout: icon sidebar + the selected pane's grouped form.
/// The window keeps its size; only the detail content changes.
struct SettingsRootView: View {
    static let sidebarWidth: CGFloat = 200

    @Bindable var model: SettingsNavigationModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                ForEach(Array(model.groups.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group) { entry in
                            SettingsSidebarRow(entry: entry).tag(entry.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(Self.sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let entry = model.selectedEntry {
                entry.makeContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(entry.id)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// Sidebar row: white glyph on a colored rounded square, then the title.
private struct SettingsSidebarRow: View {
    private static let tileSize: CGFloat = 20
    private static let tileRadius: CGFloat = 5
    private static let glyphSize: CGFloat = 11

    let entry: SettingsEntry

    var body: some View {
        Label {
            Text(entry.title)
        } icon: {
            RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                .fill(entry.tint.gradient)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .overlay {
                    Image(systemName: entry.symbol)
                        .font(.system(size: Self.glyphSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
        }
    }
}
