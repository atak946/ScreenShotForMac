import AppKit
import Observation
import ShotCore

/// Owns the editor state. The document is an immutable value; every change
/// replaces it, and committed changes register the previous snapshot with `UndoManager`.
@MainActor
@Observable
final class EditorViewModel {
    private(set) var document: EditorDocument {
        didSet {
            notifyChange()
            if document.outputRect != oldValue.outputRect || document.scale != oldValue.scale {
                onOutputSizeChange?(outputPixelSize)
            }
        }
    }

    private(set) var tool: EditorTool = .arrow { didSet { notifyChange() } }
    /// All selected annotations. Handles / style editing apply when exactly one is selected.
    var selectedIDs: Set<UUID> = [] { didSet { if selectedIDs != oldValue { notifyChange() } } }
    var style: AnnotationStyle = .default
    /// Annotation currently edited by the inline text field (hidden while editing).
    var editingTextID: UUID? { didSet { notifyChange() } }
    /// Crop rect being adjusted while the crop tool is active.
    var cropDraft: CGRect? { didSet { notifyChange() } }
    /// Bumped on every undo stack change so SwiftUI refreshes undo/redo buttons.
    private(set) var undoRevision = 0
    /// Highlighter keeps its own color so it defaults to yellow.
    var highlightColor: AnnotationColor = .highlighter
    /// Current canvas zoom in percent, published by the canvas for the toolbar.
    var zoomPercent = 100
    /// Aspect ratio the crop draft is locked to.
    var cropAspect: CropAspect = .free
    /// Last used redaction mode (Blur / Pixelate share one toolbar button).
    private(set) var redactionTool: EditorTool = .blur

    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored let renderer: AnnotationRenderer
    /// Canvas redraw hook.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Called before exporting so pending inline text is committed.
    @ObservationIgnored var beforeExport: (() -> Void)?
    @ObservationIgnored var onRequestClose: (() -> Void)?
    /// Canvas zoom hook, set by `CanvasView`.
    @ObservationIgnored var zoomHandler: ((ZoomCommand) -> Void)?
    @ObservationIgnored var onBackdrop: ((CGImage) -> Void)?
    @ObservationIgnored var onPin: ((CGImage) -> Void)?
    @ObservationIgnored var onUpload: ((CGImage) -> Void)?
    /// Called with the exported size in pixels whenever crop / padding / rotation changes it.
    @ObservationIgnored var onOutputSizeChange: ((CGSize) -> Void)?
    @ObservationIgnored var sensitiveDataDetector: SensitiveDataDetecting?
    /// Options used by Auto Redact (edited in its popover).
    var redactOptions = RedactOptions()
    /// True while Auto Redact is scanning.
    var isRedacting = false
    /// Transient glass toast shown over the canvas.
    var toast: EditorToast?
    @ObservationIgnored var toastTask: Task<Void, Never>?
    @ObservationIgnored var shouldCloseAfterSave: () -> Bool = { true }
    @ObservationIgnored let exportHandler: @MainActor (CGImage, ExportAction) -> Void
    @ObservationIgnored var textEditSnapshot: EditorDocument?

    init(document: EditorDocument, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        self.document = document
        exportHandler = onExport
        renderer = AnnotationRenderer(effects: ImageEffects(scale: document.scale))
        undoManager.levelsOfUndo = 200
    }

    /// The single selected annotation id; nil when nothing or several are selected.
    var selectedID: UUID? {
        get { selectedIDs.count == 1 ? selectedIDs.first : nil }
        set { selectedIDs = newValue.map { [$0] } ?? [] }
    }

    var selectedAnnotation: Annotation? { document.annotation(id: selectedID) }

    /// Selected annotations in z-order (back to front).
    var selectedAnnotations: [Annotation] {
        document.annotations.filter { selectedIDs.contains($0.id) }
    }

    var outputPixelSize: CGSize {
        let rect = document.outputRect
        return CGSize(width: (rect.width * document.scale).rounded(), height: (rect.height * document.scale).rounded())
    }

    var canUndo: Bool { _ = undoRevision
        return undoManager.canUndo
    }

    var canRedo: Bool { _ = undoRevision
        return undoManager.canRedo
    }

    /// Region shown on the canvas: full canvas while cropping, otherwise the crop.
    var visibleRect: CGRect { tool == .crop ? document.canvasRect : document.outputRect }

    /// Tool whose options the style controls show: the selection's kind, else the active tool.
    var contextTool: EditorTool {
        guard let kind = selectedAnnotation?.kind else { return tool }
        return EditorTool(kind: kind) ?? tool
    }

    /// Style used for new annotations created with `tool`.
    func creationStyle(for tool: EditorTool) -> AnnotationStyle {
        guard tool == .highlight else { return style }
        var copy = style
        copy.color = highlightColor
        return copy
    }

    func zoom(_ command: ZoomCommand) {
        zoomHandler?(command)
    }

    // MARK: - Document changes

    /// Replaces the document without an undo entry (live drag updates).
    func replaceLive(_ newDocument: EditorDocument) {
        document = newDocument
    }

    /// Registers an undo step back to `snapshot` if the document changed since.
    func commit(from snapshot: EditorDocument, actionName: String) {
        guard snapshot != document else { return }
        registerUndo(previous: snapshot, actionName: actionName)
    }

    /// Applies a change and registers it for undo in one step.
    func apply(_ actionName: String, _ transform: (EditorDocument) -> EditorDocument) {
        let snapshot = document
        document = transform(snapshot)
        commit(from: snapshot, actionName: actionName)
    }

    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        undoRevision += 1
    }

    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        undoRevision += 1
    }

    private func registerUndo(previous: EditorDocument, actionName: String) {
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.restore(previous, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
        undoRevision += 1
    }

    private func restore(_ snapshot: EditorDocument, actionName: String) {
        let current = document
        document = snapshot
        let remaining = selectedIDs.filter { snapshot.annotation(id: $0) != nil }
        if remaining != selectedIDs { selectedIDs = remaining }
        registerUndo(previous: current, actionName: actionName)
    }

    // MARK: - Tools & selection

    func selectTool(_ newTool: EditorTool) {
        guard newTool != tool else { return }
        if tool == .crop { cropDraft = nil }
        tool = newTool
        if newTool == .blur || newTool == .pixelate { redactionTool = newTool }
        if newTool == .crop {
            selectedIDs = []
            cropDraft = fittedCropDraft(document.outputRect)
        }
    }

    func deleteSelected() {
        delete(ids: selectedIDs)
    }

    func nudgeSelected(by delta: CGPoint) {
        let ids = selectedIDs
        guard !ids.isEmpty else { return }
        apply(String(localized: "Move", bundle: .module)) { $0.moving(ids: ids, by: delta) }
    }

    func selectAll() {
        if tool == .crop { selectTool(.select) }
        selectedIDs = Set(document.annotations.map(\.id))
    }

    private func notifyChange() {
        onChange?()
    }
}
