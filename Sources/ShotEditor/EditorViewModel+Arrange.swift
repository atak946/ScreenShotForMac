import AppKit

/// Aspect presets offered by the crop bar.
enum CropAspect: CaseIterable, Identifiable, Sendable {
    case free, square, fourThree, sixteenNine

    var id: Self { self }

    /// Width / height; nil = unconstrained.
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        }
    }

    var title: String {
        switch self {
        case .free: return String(localized: "Free", bundle: .module)
        case .square: return "1:1"
        case .fourThree: return "4:3"
        case .sixteenNine: return "16:9"
        }
    }
}

/// Z-order, duplication and crop-aspect helpers used by the context menu and crop bar.
extension EditorViewModel {
    private static let duplicateOffset: CGFloat = 16

    /// Duplicates the annotations (keeping their z-order) and selects the copies.
    func duplicate(ids: Set<UUID>) {
        let sources = document.annotations.filter { ids.contains($0.id) }
        guard !sources.isEmpty else { return }
        let offset = CGPoint(x: Self.duplicateOffset, y: Self.duplicateOffset)
        let copies = renumberedCounters(sources.map { $0.duplicated(offset: offset) })
        apply(String(localized: "Duplicate", bundle: .module)) { $0.adding(copies) }
        selectedIDs = Set(copies.map(\.id))
    }

    func bringToFront(ids: Set<UUID>) {
        reorder(ids: ids, actionName: String(localized: "Bring to Front", bundle: .module)) { others, items in others + items }
    }

    func sendToBack(ids: Set<UUID>) {
        reorder(ids: ids, actionName: String(localized: "Send to Back", bundle: .module)) { others, items in items + others }
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        selectedIDs.subtract(ids)
        apply(String(localized: "Delete", bundle: .module)) { $0.removing(ids: ids) }
    }

    /// Applies `color` to every annotation in `ids` that has a color.
    func recolor(ids: Set<UUID>, to color: AnnotationColor) {
        if ids.count == 1, ids == selectedIDs {
            setColor(color)
            return
        }
        apply(String(localized: "Change Color", bundle: .module)) { document in
            var copy = document
            copy.annotations = document.annotations.map { annotation in
                guard ids.contains(annotation.id), EditorTool(kind: annotation.kind)?.usesColor == true else { return annotation }
                var style = annotation.style
                style.color = color
                return annotation.with(style: style)
            }
            return copy
        }
    }

    /// Gives pasted / duplicated counters fresh consecutive numbers.
    func renumberedCounters(_ annotations: [Annotation]) -> [Annotation] {
        var next = document.nextCounterNumber
        return annotations.map { annotation in
            guard annotation.kind == .counter else { return annotation }
            var copy = annotation
            copy.number = next
            next += 1
            return copy
        }
    }

    func setCropAspect(_ aspect: CropAspect) {
        cropAspect = aspect
        guard tool == .crop, let draft = cropDraft else { return }
        cropDraft = fittedCropDraft(draft)
    }

    /// Largest rect with the locked aspect inside the canvas, centered on `draft`.
    func fittedCropDraft(_ draft: CGRect) -> CGRect {
        guard let ratio = cropAspect.ratio else { return draft }
        let canvas = document.canvasRect
        var size = CGSize(width: canvas.width, height: canvas.width / ratio)
        if size.height > canvas.height { size = CGSize(width: canvas.height * ratio, height: canvas.height) }
        let x = min(max(draft.midX - size.width / 2, canvas.minX), canvas.maxX - size.width)
        let y = min(max(draft.midY - size.height / 2, canvas.minY), canvas.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func reorder(ids: Set<UUID>, actionName: String, _ arrange: ([Annotation], [Annotation]) -> [Annotation]) {
        let items = document.annotations.filter { ids.contains($0.id) }
        guard !items.isEmpty else { return }
        apply(actionName) { document in
            var copy = document
            copy.annotations = arrange(document.annotations.filter { !ids.contains($0.id) }, items)
            return copy
        }
    }
}
