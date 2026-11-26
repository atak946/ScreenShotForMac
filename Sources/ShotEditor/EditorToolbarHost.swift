import AppKit
import SwiftUI

/// Hosts the SwiftUI editor bar inside a real unified `NSToolbar`.
/// AppKit then vertically aligns the traffic lights and the bar itself — no private
/// titlebar view manipulation, so it stays correct across macOS versions and window states.
@MainActor
final class EditorToolbarHost: NSObject, NSToolbarDelegate {
    private static let itemIdentifier = NSToolbarItem.Identifier("app.screenshotformac.editor.bar")
    /// Horizontal space taken by the traffic lights and toolbar insets.
    static let reservedWidth: CGFloat = 128

    private let hostingView: NSHostingView<EditorToolbarView>
    private let widthConstraint: NSLayoutConstraint

    init(viewModel: EditorViewModel) {
        hostingView = NSHostingView(rootView: EditorToolbarView(viewModel: viewModel))
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        widthConstraint = hostingView.widthAnchor.constraint(equalToConstant: 600)
        // Below required so AppKit can shave a few points instead of moving the item to overflow.
        widthConstraint.priority = .defaultHigh
        super.init()
        NSLayoutConstraint.activate([
            widthConstraint,
            hostingView.heightAnchor.constraint(equalToConstant: EditorToolbarView.height),
        ])
    }

    func install(in window: NSWindow) {
        let toolbar = NSToolbar(identifier: "app.screenshotformac.editor")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.showsBaselineSeparator = true
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        updateWidth(for: window)
    }

    /// Keeps the bar spanning the full titlebar width (minus the traffic lights).
    func updateWidth(for window: NSWindow) {
        widthConstraint.constant = max(window.frame.width - Self.reservedWidth, 320)
    }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.itemIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.itemIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.itemIdentifier else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.view = hostingView
        item.visibilityPriority = .high
        return item
    }
}
