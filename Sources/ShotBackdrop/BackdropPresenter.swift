import AppKit
import ShotCore

/// Opens backdrop composer windows. Windows are retained until closed.
@MainActor
public final class BackdropPresenter: BackdropPresenting {
    private var controllers: [UUID: BackdropWindowController] = [:]
    private let store: BackdropPresetStore

    public init() {
        store = BackdropPresetStore()
    }

    public init(store: BackdropPresetStore) {
        self.store = store
    }

    public func openBackdrop(for capture: CaptureResult, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        let id = UUID()
        let model = BackdropViewModel(capture: capture, store: store, onExport: onExport)
        let controller = BackdropWindowController(model: model) { [weak self] in
            self?.controllers[id] = nil
        }
        controllers[id] = controller
        controller.present()
        Log.editor.info("Opened backdrop for \(capture.image.width)x\(capture.image.height) capture")
    }
}
