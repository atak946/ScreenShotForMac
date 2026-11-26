import AppKit
import ShotCore
import SwiftUI

/// Opens Combine / Split windows. Windows are retained until closed.
@MainActor
public final class CombinePresenter {
    private var controllers: [UUID: CombineWindowController] = [:]

    public init() {}

    /// Opens a window with `captures` in the strip. A single capture opens in Split mode.
    /// `onExport` receives the combined image (or each slice) with the requested action.
    public func open(with captures: [CaptureResult], onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        let id = UUID()
        let model = CombineViewModel(captures: captures, onExport: onExport)
        let controller = CombineWindowController(model: model) { [weak self] in
            self?.controllers[id] = nil
        }
        controllers[id] = controller
        controller.present()
        Log.editor.info("Opened combine window with \(captures.count) images")
    }
}

/// One Combine / Split window.
@MainActor
final class CombineWindowController: NSWindowController, NSWindowDelegate {
    private static let initialSize = CGSize(width: 1100, height: 720)

    private let onClose: () -> Void

    init(model: CombineViewModel, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let hosting = NSHostingController(rootView: CombineRootView(model: model))
        hosting.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.title = String(localized: "Combine Images", bundle: .module)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setContentSize(Self.initialSize)
        window.contentMinSize = CombineRootView.minimumSize
        super.init(window: window)
        window.delegate = self
        model.window = window
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
        onClose()
    }
}
