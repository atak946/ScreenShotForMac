import AppKit
import ShotCore

/// Menu-bar submenu with the most recent history items. Rebuilds itself on every open.
/// Keep a strong reference to this object for as long as `menu` is in use.
@MainActor
public final class RecentHistoryMenu: NSObject, NSMenuDelegate {
    public let menu: NSMenu
    private let store: HistoryStore
    private let limit: Int
    private let onSelect: @MainActor (HistoryItem) -> Void
    private let onShowAll: (@MainActor () -> Void)?

    private static let thumbnailHeight: CGFloat = 32
    private static let thumbnailMaxWidth: CGFloat = 56

    public init(
        store: HistoryStore,
        limit: Int = 10,
        title: String? = nil,
        onSelect: @escaping @MainActor (HistoryItem) -> Void,
        onShowAll: (@MainActor () -> Void)? = nil
    ) {
        self.store = store
        self.limit = limit
        self.onSelect = onSelect
        self.onShowAll = onShowAll
        menu = NSMenu(title: title ?? String(localized: "Recent Captures", bundle: .module))
        super.init()
        menu.delegate = self
        rebuild()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        let items = store.recentItems(limit: limit)
        if items.isEmpty {
            let empty = NSMenuItem(title: String(localized: "No Recent Captures", bundle: .module), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            items.forEach { menu.addItem(menuItem(for: $0)) }
        }
        guard onShowAll != nil else { return }
        menu.addItem(.separator())
        let showAll = NSMenuItem(
            title: String(localized: "Show All History…", bundle: .module),
            action: #selector(showAllSelected),
            keyEquivalent: ""
        )
        showAll.target = self
        menu.addItem(showAll)
    }

    private func menuItem(for item: HistoryItem) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title(for: item), action: #selector(itemSelected(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = item.id
        menuItem.image = thumbnail(for: item)
        return menuItem
    }

    private func title(for item: HistoryItem) -> String {
        let time = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        let prefix = item.kind == .image ? "" : (item.kind == .gif ? "GIF · " : String(localized: "Video", bundle: .module) + " · ")
        guard let app = item.sourceAppName else { return "\(prefix)\(time)" }
        return "\(prefix)\(app) — \(time)"
    }

    private func thumbnail(for item: HistoryItem) -> NSImage? {
        guard let source = ThumbnailCache.shared.imageSync(for: item.thumbnailURL) else {
            return NSImage(systemSymbolName: item.kind == .image ? "photo" : "video", accessibilityDescription: nil)
        }
        let pixel = source.size
        guard pixel.width > 0, pixel.height > 0 else { return nil }
        let factor = min(Self.thumbnailHeight / pixel.height, Self.thumbnailMaxWidth / pixel.width)
        let size = NSSize(width: (pixel.width * factor).rounded(), height: (pixel.height * factor).rounded())
        return NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
    }

    @objc
    private func itemSelected(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        onSelect(item)
    }

    @objc
    private func showAllSelected() {
        onShowAll?()
    }
}
