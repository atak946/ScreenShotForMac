import AppKit
import ShotCore

/// Optional extra actions offered by the editor toolbar. Each receives a capture
/// built from the flattened current image (same scale / screenRect / date / app).
struct EditorExtraActions {
    let onBackdrop: (@MainActor (CaptureResult) -> Void)?
    let onPin: (@MainActor (CaptureResult) -> Void)?
    var onUpload: (@MainActor (CaptureResult) -> Void)?
    var sensitiveDataDetector: SensitiveDataDetecting?
}

/// Opens one editor window per capture. Windows are retained until closed.
@MainActor
public final class EditorPresenter: EditorPresenting {
    private let settings: AppSettings
    private let extraActions: EditorExtraActions
    private var controllers: [UUID: EditorWindowController] = [:]

    /// - Parameters:
    ///   - settings: read for `editorCloseAfterSave`.
    ///   - onBackdrop: shows a "Backdrop…" toolbar button when non-nil.
    ///   - onPin: shows a "Pin" toolbar button when non-nil.
    ///   - onUpload: shows an "Upload" toolbar button next to Copy when non-nil.
    ///   - sensitiveDataDetector: enables Auto Redact (toolbar button + "…" menu) when non-nil.
    public init(
        settings: AppSettings = .shared,
        onBackdrop: (@MainActor (CaptureResult) -> Void)? = nil,
        onPin: (@MainActor (CaptureResult) -> Void)? = nil,
        onUpload: (@MainActor (CaptureResult) -> Void)? = nil,
        sensitiveDataDetector: SensitiveDataDetecting? = nil
    ) {
        self.settings = settings
        extraActions = EditorExtraActions(
            onBackdrop: onBackdrop, onPin: onPin, onUpload: onUpload, sensitiveDataDetector: sensitiveDataDetector
        )
    }

    public func openEditor(for capture: CaptureResult, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        openEditor(for: capture, onExport: onExport, onClose: nil)
    }

    /// Same as `openEditor(for:onExport:)`; `onClose` runs after the window closes (after any export).
    public func openEditor(
        for capture: CaptureResult,
        onExport: @escaping @MainActor (CGImage, ExportAction) -> Void,
        onClose: (@MainActor () -> Void)?
    ) {
        let id = UUID()
        let controller = EditorWindowController(
            capture: capture,
            settings: settings,
            extraActions: extraActions,
            onExport: onExport
        ) { [weak self] in
            self?.controllers[id] = nil
            onClose?()
        }
        controllers[id] = controller
        controller.present()
        Log.editor.info("Opened editor for \(capture.image.width)x\(capture.image.height) capture")
    }
}
