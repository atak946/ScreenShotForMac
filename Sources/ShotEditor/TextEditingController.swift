import AppKit

/// Hosts an inline NSTextView over the canvas for creating / editing text annotations.
/// Enter commits, Shift+Enter or Option+Enter inserts a newline, Esc cancels,
/// clicking outside commits.
@MainActor
final class TextEditingController: NSObject, NSTextViewDelegate {
    private static let minimumWidth: CGFloat = 60
    private static let trailingSlack: CGFloat = 16

    private weak var canvas: CanvasView?
    private var textView: NSTextView?
    private var annotation: Annotation?
    private var isFinishing = false

    init(canvas: CanvasView) {
        self.canvas = canvas
    }

    var isEditing: Bool { textView != nil }

    func begin(annotation: Annotation) {
        guard let canvas else { return }
        removeTextView()
        self.annotation = annotation
        let textView = makeTextView(for: annotation)
        canvas.addSubview(textView)
        self.textView = textView
        reposition()
        canvas.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
    }

    private func makeTextView(for annotation: Annotation) -> NSTextView {
        let textView = NSTextView(frame: .zero)
        textView.string = annotation.text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = annotation.style.filled
        textView.backgroundColor = annotation.style.color.nsColor
        textView.textColor = TextLayout.textColor(for: annotation.style)
        textView.insertionPointColor = TextLayout.textColor(for: annotation.style)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = self
        return textView
    }

    /// Keeps the editor aligned with the annotation when zoom / pan changes.
    func reposition() {
        guard let canvas, let textView, let annotation else { return }
        let layout = canvas.layout
        let font = TextLayout.font(size: annotation.style.fontSize * layout.zoom)
        textView.font = font
        textView.typingAttributes[.font] = font
        let used = usedSize(of: textView, font: font)
        let origin = layout.toView(annotation.start)
        textView.frame = CGRect(
            x: origin.x,
            y: origin.y,
            width: max(used.width + Self.trailingSlack, Self.minimumWidth),
            height: used.height
        )
    }

    private func usedSize(of textView: NSTextView, font: NSFont) -> CGSize {
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else {
            return CGSize(width: Self.minimumWidth, height: lineHeight)
        }
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).size
        return CGSize(width: ceil(used.width), height: max(ceil(used.height), lineHeight))
    }

    func commit() {
        finish(with: textView?.string)
    }

    func cancel() {
        finish(with: nil)
    }

    private func finish(with text: String?) {
        guard isEditing, !isFinishing, let canvas else { return }
        isFinishing = true
        removeTextView()
        annotation = nil
        canvas.viewModel.finishTextEdit(text: text)
        canvas.window?.makeFirstResponder(canvas)
        isFinishing = false
    }

    private func removeTextView() {
        textView?.delegate = nil
        textView?.removeFromSuperview()
        textView = nil
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        reposition()
    }

    func textDidEndEditing(_ notification: Notification) {
        commit()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            cancel()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            let flags = NSApp.currentEvent?.modifierFlags ?? []
            if flags.contains(.shift) || flags.contains(.option) {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else {
                commit()
            }
            return true
        default:
            return false
        }
    }
}
