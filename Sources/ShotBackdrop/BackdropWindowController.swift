import AppKit
import ShotCore
import SwiftUI

/// One backdrop composer window per capture.
@MainActor
final class BackdropWindowController: NSWindowController, NSWindowDelegate {
    private static let initialSize = CGSize(width: 1100, height: 720)

    private let model: BackdropViewModel
    private let onClose: () -> Void

    init(model: BackdropViewModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
        let hosting = NSHostingController(rootView: BackdropRootView(model: model))
        hosting.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.title = String(localized: "Backdrop", bundle: .module)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setContentSize(Self.initialSize)
        window.contentMinSize = BackdropRootView.minimumSize
        super.init(window: window)
        window.delegate = self
        model.onRequestClose = { [weak window] in window?.performClose(nil) }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        guard let window else { return }
        WindowActivation.present(window)
    }

    func windowWillClose(_ notification: Notification) {
        model.rememberStyle()
        onClose()
    }
}
