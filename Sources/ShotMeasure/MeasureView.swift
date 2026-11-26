import AppKit
import ShotCore

/// Shows the frozen snapshot, forwards input and hosts the guide canvas.
@MainActor
final class MeasureView: NSView {
    private let canvas: MeasureCanvasView
    private weak var ownerWindow: MeasureOverlayWindow?
    private var trackingArea: NSTrackingArea?

    init(frame: CGRect, snapshot: CGImage) {
        canvas = MeasureCanvasView(frame: CGRect(origin: .zero, size: frame.size))
        super.init(frame: frame)
        wantsLayer = true
        layer?.contents = snapshot
        layer?.contentsGravity = .resize
        canvas.autoresizingMask = [.width, .height]
        addSubview(canvas)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func attach(to owner: MeasureOverlayWindow) {
        ownerWindow = owner
    }

    func show(_ scene: MeasureScene) {
        canvas.scene = scene
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    private var delegate: MeasureOverlayDelegate? { ownerWindow?.overlayDelegate }

    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseMoved(with event: NSEvent) { delegate?.overlayMouseMoved() }
    override func mouseEntered(with event: NSEvent) { delegate?.overlayMouseMoved() }
    override func mouseDown(with event: NSEvent) { delegate?.overlayMouseDown() }
    override func mouseDragged(with event: NSEvent) { delegate?.overlayMouseDragged() }
    override func mouseUp(with event: NSEvent) { delegate?.overlayMouseUp() }
    override func rightMouseDown(with event: NSEvent) { delegate?.overlayCancelled() }
}

/// Transparent layer above the snapshot that renders the current `MeasureScene`:
/// guide lines are drawn, labels are glass pills.
@MainActor
final class MeasureCanvasView: NSView {
    var scene: MeasureScene = .empty {
        didSet {
            guard scene != oldValue else { return }
            needsDisplay = true
            updatePills()
        }
    }

    private let pills = (0..<4).map { _ in OverlayPill() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        pills.forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    /// Lets every mouse event reach the parent `MeasureView`.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        MeasureDrawing.draw(scene)
    }

    private func updatePills() {
        let placements = MeasureLabelLayout.placements(for: scene)
        for (pill, placement) in zip(pills, placements) {
            guard let placement else {
                pill.hide()
                continue
            }
            let size = pill.fittingSize(for: placement.text)
            pill.show(placement.text, origin: MeasureLabelLayout.origin(for: placement, size: size, in: bounds))
        }
    }
}
