import AppKit
import ShotCore

extension EditorViewModel {
    // MARK: - Style

    /// Updates the current style and applies it to the selected annotation.
    func updateStyle(_ actionName: String, _ transform: (AnnotationStyle) -> AnnotationStyle) {
        style = transform(style)
        guard let annotation = selectedAnnotation else { return }
        let newStyle = transform(annotation.style)
        guard newStyle != annotation.style else { return }
        apply(actionName) { $0.replacing(annotation.with(style: newStyle)) }
    }

    func setColor(_ color: AnnotationColor) {
        if contextTool == .highlight {
            highlightColor = color
            if let annotation = selectedAnnotation, annotation.kind == .highlight {
                var style = annotation.style
                style.color = color
                apply(String(localized: "Change Color", bundle: .module)) { $0.replacing(annotation.with(style: style)) }
            }
            return
        }
        updateStyle(String(localized: "Change Color", bundle: .module)) { style in
            var copy = style
            copy.color = color
            return copy
        }
    }

    func setLineWidth(_ width: CGFloat) {
        updateStyle(String(localized: "Change Line Width", bundle: .module)) { style in
            var copy = style
            copy.lineWidth = width
            return copy
        }
    }

    func setFontSize(_ size: CGFloat) {
        updateStyle(String(localized: "Change Font Size", bundle: .module)) { style in
            var copy = style
            copy.fontSize = size
            return copy
        }
    }

    func setFilled(_ filled: Bool) {
        updateStyle(String(localized: "Change Fill", bundle: .module)) { style in
            var copy = style
            copy.filled = filled
            return copy
        }
    }

    func setDashed(_ dashed: Bool) {
        updateStyle(String(localized: "Change Line Style", bundle: .module)) { style in
            var copy = style
            copy.dashed = dashed
            return copy
        }
    }

    func setDoubleHeaded(_ doubleHeaded: Bool) {
        updateStyle(String(localized: "Change Arrow Style", bundle: .module)) { style in
            var copy = style
            copy.doubleHeaded = doubleHeaded
            return copy
        }
    }

    func setCornerRadius(_ radius: CGFloat) {
        updateStyle(String(localized: "Change Corner Radius", bundle: .module)) { style in
            var copy = style
            copy.cornerRadius = radius
            return copy
        }
    }

    // MARK: - Text editing

    /// Starts editing a text annotation; creates a new one at `point` when `id` is nil.
    func beginTextEdit(existing id: UUID?, at point: CGPoint) -> Annotation {
        textEditSnapshot = document
        if let existing = document.annotation(id: id) {
            editingTextID = existing.id
            selectedID = existing.id
            return existing
        }
        let annotation = Annotation(kind: .text, start: point, style: creationStyle(for: .text))
        replaceLive(document.adding(annotation))
        editingTextID = annotation.id
        selectedID = annotation.id
        return annotation
    }

    func finishTextEdit(text: String?) {
        guard let id = editingTextID, let snapshot = textEditSnapshot else { return }
        textEditSnapshot = nil
        editingTextID = nil
        guard let text, let annotation = document.annotation(id: id) else {
            // Cancelled: restore the state from before editing started.
            replaceLive(snapshot)
            if snapshot.annotation(id: id) == nil { selectedID = nil }
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            selectedID = nil
            replaceLive(document.removing(id: id))
        } else {
            replaceLive(document.replacing(annotation.with(text: text)))
        }
        commit(from: snapshot, actionName: String(localized: "Edit Text", bundle: .module))
    }

    // MARK: - Crop

    func applyCrop() {
        guard let draft = cropDraft?.intersection(document.canvasRect), draft.width >= 4, draft.height >= 4 else {
            cancelCrop()
            return
        }
        let isFull = draft.insetBy(dx: -0.5, dy: -0.5).contains(document.canvasRect)
        apply(String(localized: "Crop", bundle: .module)) { $0.withCrop(isFull ? nil : draft.integral) }
        selectTool(.select)
    }

    func cancelCrop() {
        selectTool(.select)
    }

    // MARK: - Export

    func flatten() -> CGImage? {
        renderer.flatten(document)
    }

    /// Copy and Save As keep the editor open (Save As may be cancelled in its panel);
    /// Save closes the editor afterwards when `AppSettings.editorCloseAfterSave` is on.
    func export(_ action: ExportAction) {
        guard let image = flattenForExport() else { return }
        exportHandler(image, action)
        if action == .save, shouldCloseAfterSave() { onRequestClose?() }
    }

    func backdrop() {
        guard let handler = onBackdrop, let image = flattenForExport() else { return }
        handler(image)
    }

    func pin() {
        guard let handler = onPin, let image = flattenForExport() else { return }
        handler(image)
    }

    func upload() {
        guard let handler = onUpload, let image = flattenForExport() else { return }
        handler(image)
    }

    private func flattenForExport() -> CGImage? {
        beforeExport?()
        guard let image = flatten() else {
            Log.editor.error("Export aborted: flatten produced no image")
            NSSound.beep()
            return nil
        }
        return image
    }
}
