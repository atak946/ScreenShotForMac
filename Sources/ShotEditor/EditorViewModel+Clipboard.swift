import AppKit
import ShotCore

/// Internal annotation clipboard shared by all editor windows.
@MainActor
final class AnnotationClipboard {
    static let shared = AnnotationClipboard()

    private(set) var annotations: [Annotation] = []
    /// General pasteboard change count when the annotation was copied.
    private(set) var pasteboardChangeCount = -1
    /// Accumulates the paste offset so repeated pastes cascade.
    var pasteCount = 0

    func store(_ annotations: [Annotation]) {
        self.annotations = annotations
        pasteboardChangeCount = NSPasteboard.general.changeCount
        pasteCount = 0
    }

    /// True when nothing else was copied to the system pasteboard since our copy.
    var isCurrent: Bool { !annotations.isEmpty && pasteboardChangeCount == NSPasteboard.general.changeCount }
}

extension EditorViewModel {
    private static let pasteOffset: CGFloat = 16
    private static let maxPastedImageFraction: CGFloat = 0.6

    /// Copies the selected annotations internally. Returns false when nothing is selected.
    func copySelection() -> Bool {
        let annotations = selectedAnnotations
        guard !annotations.isEmpty else { return false }
        AnnotationClipboard.shared.store(annotations)
        return true
    }

    /// Pastes the internal annotation, or an image from the pasteboard as an image annotation.
    func paste() {
        let clipboard = AnnotationClipboard.shared
        if !clipboard.isCurrent, selectedIDs.isEmpty, let image = pasteboardImage() {
            insertImage(image.cgImage, pointSize: image.size)
            return
        }
        guard !clipboard.annotations.isEmpty else {
            NSSound.beep()
            return
        }
        clipboard.pasteCount += 1
        let offset = Self.pasteOffset * CGFloat(clipboard.pasteCount)
        let pasted = renumberedCounters(clipboard.annotations.map { $0.duplicated(offset: CGPoint(x: offset, y: offset)) })
        if tool == .crop { selectTool(.select) }
        apply(String(localized: "Paste", bundle: .module)) { $0.adding(pasted) }
        selectedIDs = Set(pasted.map(\.id))
    }

    func insertImage(_ image: CGImage, pointSize: CGSize) {
        let output = visibleRect
        let limit = CGSize(width: output.width * Self.maxPastedImageFraction, height: output.height * Self.maxPastedImageFraction)
        let fit = min(1, limit.width / max(pointSize.width, 1), limit.height / max(pointSize.height, 1))
        let size = CGSize(width: pointSize.width * fit, height: pointSize.height * fit)
        let origin = CGPoint(x: output.midX - size.width / 2, y: output.midY - size.height / 2)
        var imageStyle = style
        imageStyle.opacity = 1
        let annotation = Annotation(
            kind: .image, start: origin, end: CGPoint(x: origin.x + size.width, y: origin.y + size.height),
            style: imageStyle, image: AnnotationImage(cgImage: image)
        )
        if tool == .crop { selectTool(.select) }
        apply(String(localized: "Paste Image", bundle: .module)) { $0.adding(annotation) }
        selectedID = annotation.id
        Log.editor.debug("Inserted pasted image \(image.width)x\(image.height)")
    }

    private func pasteboardImage() -> (cgImage: CGImage, size: CGSize)? {
        guard let image = NSImage(pasteboard: NSPasteboard.general),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let size = image.size.width > 0 ? image.size : CGSize(width: cgImage.width, height: cgImage.height)
        return (cgImage, size)
    }
}
