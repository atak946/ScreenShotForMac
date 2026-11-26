import AppKit
import ShotCore

/// Flipped canvas that renders the document zoomed-to-fit and handles mouse / keyboard input.
@MainActor
final class CanvasView: NSView {
    static let handleSize: CGFloat = 9
    static let hitTolerance: CGFloat = 6

    let viewModel: EditorViewModel
    var dragState: CanvasDragState = .idle
    var viewport: CanvasViewport = .fit
    var isSpacePressed = false
    /// Rubber-band rect in document coordinates while marquee-selecting.
    var marqueeRect: CGRect? { didSet { needsDisplay = true } }
    private var lastVisibleRect: CGRect?
    lazy var textEditor = TextEditingController(canvas: self)

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        wantsLayer = true
        viewModel.onChange = { [weak self] in self?.modelDidChange() }
        viewModel.beforeExport = { [weak self] in self?.textEditor.commit() }
        viewModel.zoomHandler = { [weak self] command in self?.handleZoom(command) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var layout: CanvasLayout {
        CanvasLayout(visibleRect: viewModel.visibleRect, viewBounds: bounds, viewport: viewport)
    }

    private func modelDidChange() {
        let visible = viewModel.visibleRect
        if visible != lastVisibleRect {
            // Crop, padding or rotation changed the shown region: go back to fit.
            lastVisibleRect = visible
            viewport = .fit
            textEditor.reposition()
        }
        publishZoom()
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        if !textEditor.isEditing, let window, window.firstResponder !== self, !(window.firstResponder is NSText) {
            window.makeFirstResponder(self)
        }
    }

    override func resetCursorRects() {
        let cursor: NSCursor = isSpacePressed ? .openHand : viewModel.tool.cursor
        addCursorRect(isSpacePressed ? bounds : layout.imageFrame, cursor: cursor)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        textEditor.reposition()
        publishZoom()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawBackground(dirtyRect)

        let layout = layout
        drawDocument(layout: layout, in: context)
        if viewModel.tool == .crop {
            drawCropOverlay(layout: layout, in: context)
        } else {
            drawSelection(layout: layout, in: context)
            drawGroupSelection(layout: layout, in: context)
            drawMarquee(layout: layout, in: context)
        }
    }

    private func drawDocument(layout: CanvasLayout, in context: CGContext) {
        drawImageBacking(layout.imageFrame, transparent: viewModel.document.backgroundColor == nil, in: context)

        context.saveGState()
        context.clip(to: layout.imageFrame)
        context.translateBy(x: layout.origin.x, y: layout.origin.y)
        context.scaleBy(x: layout.zoom, y: layout.zoom)
        context.translateBy(x: -layout.visibleRect.minX, y: -layout.visibleRect.minY)
        let hidden: Set<UUID> = viewModel.editingTextID.map { [$0] } ?? []
        viewModel.renderer.draw(viewModel.document, in: context, hiddenIDs: hidden, nearestNeighbor: layout.usesNearestNeighbor)
        context.restoreGState()
        drawHairline(around: layout.imageFrame, in: context)
    }

    private func drawSelection(layout: CanvasLayout, in context: CGContext) {
        guard let annotation = viewModel.selectedAnnotation, viewModel.editingTextID == nil else { return }
        let frame = layout.toView(HitTesting.bounds(of: annotation)).insetBy(dx: -3, dy: -3)
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(frame)
        context.restoreGState()
        HitTesting.handles(for: annotation).forEach { drawHandle(at: layout.toView($0.point), in: context) }
    }

    private func drawCropOverlay(layout: CanvasLayout, in context: CGContext) {
        guard let draft = viewModel.cropDraft else { return }
        let cropFrame = layout.toView(draft)
        context.saveGState()
        context.addRect(layout.imageFrame)
        context.addRect(cropFrame)
        context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.stroke(cropFrame)
        drawThirds(in: cropFrame, context: context)
        context.restoreGState()
        Resizing.cornerHandles(of: draft).forEach { drawHandle(at: layout.toView($0.point), in: context) }
        drawCropSize(draft, frame: cropFrame)
    }

    private func drawThirds(in frame: CGRect, context: CGContext) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(0.5)
        for index in 1...2 {
            let fraction = CGFloat(index) / 3
            context.move(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY))
            context.addLine(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY))
            context.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction))
            context.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction))
        }
        context.strokePath()
    }

    private func drawCropSize(_ draft: CGRect, frame: CGRect) {
        let scale = viewModel.document.scale
        let label = "\(Int((draft.width * scale).rounded())) × \(Int((draft.height * scale).rounded()))"
        let string = NSAttributedString(string: label, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ])
        let size = string.size()
        let badge = CGRect(x: frame.minX, y: max(frame.minY - size.height - 8, 2), width: size.width + 10, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        string.draw(at: CGPoint(x: badge.minX + 5, y: badge.minY + 2))
    }

    func drawHandle(at point: CGPoint, in context: CGContext) {
        let size = Self.handleSize
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        context.saveGState()
        context.setShadow(offset: .zero, blur: 2, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: rect)
        context.restoreGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))
    }
}
