import AppKit
import ShotCore
import SwiftUI

/// Shows the capture history browser in one reusable window.
@MainActor
public final class HistoryPresenter: HistoryPresenting {
    public let store: HistoryStore
    private let model: HistoryBrowserModel
    private var window: NSWindow?
    private var recentMenuController: RecentHistoryMenu?

    private static let defaultSize = NSSize(width: 960, height: 660)

    /// Capture hotkey shown in the empty state (e.g. "⌥⇧1"). Set by the app when it differs.
    public var captureShortcutHint = "⌥⇧1"

    public init(store: HistoryStore) {
        self.store = store
        model = HistoryBrowserModel(store: store)
    }

    public func showHistory(onOpen: @escaping @MainActor (CaptureResult) -> Void) {
        model.onOpen = onOpen
        let window = window ?? makeWindow()
        self.window = window
        WindowActivation.present(window)
    }

    /// Builds a "Recent Captures" submenu (last `limit` items with thumbnails) that refreshes
    /// itself every time it opens. Includes a "Show All History…" entry. The presenter keeps
    /// the most recently built menu's controller alive.
    public func recentMenu(limit: Int = 10, onOpen: @escaping @MainActor (CaptureResult) -> Void) -> NSMenu {
        let controller = RecentHistoryMenu(
            store: store,
            limit: limit,
            onSelect: { [weak self] item in
                guard let self else { return }
                HistoryItemActions.open(item, store: store, onOpen: onOpen)
            },
            onShowAll: { [weak self] in self?.showHistory(onOpen: onOpen) }
        )
        recentMenuController = controller
        return controller.menu
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: HistoryWindowView(model: model, captureShortcut: captureShortcutHint))
        hosting.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hosting)
        window.title = String(localized: "Capture History", bundle: .module)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(Self.defaultSize)
        window.contentMinSize = HistoryWindowView.minimumSize
        window.center()
        window.setFrameAutosaveName("HistoryWindow")
        return window
    }
}
