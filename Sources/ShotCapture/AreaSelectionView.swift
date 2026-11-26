import AppKit
import ShotCore

/// Content view of one area-selection overlay window. Shows the frozen snapshot (if any)
/// as its layer contents, with selection chrome, size pill, toolbar and magnifier on top.
@MainActor
final class AreaSelectionView: OverlayInputView {
    private static let edgeMargin: CGFloat = DS.Space.xs
    private static let toolbarGap: CGFloat = DS.Space.s
    private static let sizePillOffset: CGFloat = 14
    private static let magnifierGap: CGFloat = 24

    var onConfirm: (() -> Void)? {
        didSet { toolbar.onCapture = onConfirm }
    }

    var onCancel: (() -> Void)? {
        didSet { toolbar.onCancel = onCancel }
    }

    var onQuickAction: ((ExportAction) -> Void)? {
        didSet { toolbar.onQuickAction = onQuickAction }
    }

    private let surface: SelectionSurface
    private let chrome: SelectionChromeView
    private let magnifier: MagnifierView
    private let sizePill = OverlayPill()
    private let toolbar = SelectionToolbar()

    init(surface: SelectionSurface) {
        self.surface = surface
        let bounds = CGRect(origin: .zero, size: surface.frame.size)
        chrome = SelectionChromeView(frame: bounds)
        magnifier = MagnifierView(frame: CGRect(origin: .zero, size: MagnifierView.totalSize))
        super.init(frame: bounds)

        wantsLayer = true
        if let snapshot = surface.snapshot {
            layer?.contents = snapshot.image
            layer?.contentsGravity = .resize
            layer?.contentsScale = snapshot.scale
        }
        chrome.autoresizingMask = [.width, .height]
        magnifier.isHidden = true
        toolbar.isHidden = true
        [chrome, magnifier, sizePill, toolbar].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func update(state: SelectionRenderState) {
        let isCursorHere = surface.frame.contains(state.cursor)
        let localCursor = toLocal(state.cursor)
        chrome.selection = state.selection.map(toLocal)
        chrome.highlight = state.highlight.map(toLocal)
        chrome.showsHandles = state.isEditing
        chrome.needsDisplay = true

        updateSizePill(selection: chrome.selection, cursor: isCursorHere && state.showsSizeLabel ? localCursor : nil)
        updateToolbar(selection: state.isEditing ? chrome.selection : nil)
        updateMagnifier(enabled: state.showsMagnifier && isCursorHere, cursor: state.cursor)
    }

    /// Live W×H pill above-right of the cursor (the magnifier sits below-right).
    private func updateSizePill(selection: CGRect?, cursor: CGPoint?) {
        guard let selection, let cursor else {
            sizePill.hide()
            return
        }
        let text = "\(Int(selection.width.rounded())) × \(Int(selection.height.rounded()))"
        let size = sizePill.fittingSize(for: text)
        var origin = CGPoint(x: cursor.x + Self.sizePillOffset, y: cursor.y + Self.sizePillOffset)
        origin.x = min(max(origin.x, bounds.minX + Self.edgeMargin), bounds.maxX - size.width - Self.edgeMargin)
        if origin.y + size.height > bounds.maxY - Self.edgeMargin {
            origin.y = cursor.y - Self.sizePillOffset - size.height
        }
        sizePill.show(text, origin: origin)
    }

    private func updateToolbar(selection: CGRect?) {
        guard let selection, bounds.intersects(selection) else {
            toolbar.isHidden = true
            return
        }
        toolbar.setSize(selection.size)
        let size = toolbar.fittingSize
        let gap = Self.toolbarGap
        let margin = Self.edgeMargin
        var origin = CGPoint(x: selection.maxX - size.width, y: selection.minY - gap - size.height)
        if origin.y < bounds.minY + margin { origin.y = selection.maxY + gap }
        if origin.y + size.height > bounds.maxY - margin { origin.y = selection.minY + gap }
        origin.x = min(max(origin.x, bounds.minX + margin), bounds.maxX - size.width - margin)
        toolbar.frame = CGRect(origin: origin, size: size)
        toolbar.isHidden = false
    }

    private func updateMagnifier(enabled: Bool, cursor: CGPoint) {
        guard enabled, let snapshot = surface.snapshot else {
            magnifier.isHidden = true
            return
        }
        magnifier.isHidden = false
        let pixel = CoordinateSpace.pixelPoint(
            forGlobalPoint: cursor,
            displayFrame: snapshot.frame,
            pixelScale: snapshot.scale
        )
        let pointX = Int((cursor.x - snapshot.frame.minX).rounded(.down))
        let pointY = Int((snapshot.frame.maxY - cursor.y).rounded(.down))
        magnifier.update(image: snapshot.image, pixel: pixel, pointLabel: "\(pointX), \(pointY)")
        magnifier.setFrameOrigin(magnifierOrigin(for: toLocal(cursor)))
    }

    private func toLocal(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - surface.frame.minX, y: point.y - surface.frame.minY)
    }

    private func toLocal(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -surface.frame.minX, dy: -surface.frame.minY)
    }

    /// Places the loupe below-right of the cursor, flipping to stay on screen.
    private func magnifierOrigin(for cursor: CGPoint) -> CGPoint {
        let gap = Self.magnifierGap
        let size = MagnifierView.totalSize
        var x = cursor.x + gap
        var y = cursor.y - gap - size.height
        if x + size.width > bounds.maxX { x = cursor.x - gap - size.width }
        if y < bounds.minY { y = cursor.y + gap }
        return CGPoint(x: x, y: y)
    }
}
