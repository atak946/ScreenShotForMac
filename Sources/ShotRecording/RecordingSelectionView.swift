import AppKit
import ShotCore

/// Draws the dimmed overlay, the drag rectangle or hovered window, and a usage hint.
@MainActor
final class RecordingSelectionView: NSView {
    private enum KeyCode {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let letterF: UInt16 = 3
    }

    private static let dimColor = DS.Palette.overlayDim
    private static let accent = DS.Palette.recording
    private static let hintTopInset: CGFloat = 80
    private static let hint = String(
        localized: "Drag to record an area · Click a window · F or Enter for full screen · Esc to cancel",
        bundle: .module
    )

    private let screenFrame: CGRect
    private weak var controller: RecordingSelectionController?
    private var state = RecordingSelectionState()
    private let hintPill = OverlayPill(font: DS.Font.label, verticalPadding: DS.Space.s)
    private let sizePill = OverlayPill()

    init(screenFrame: CGRect, controller: RecordingSelectionController) {
        self.screenFrame = screenFrame
        self.controller = controller
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        addSubview(sizePill)
        addSubview(hintPill)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func update(_ newState: RecordingSelectionState) {
        if newState != state {
            state = newState
            needsDisplay = true
        }
        updatePills()
    }

    // MARK: - Events

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseEntered(with event: NSEvent) { updatePills() }
    override func mouseExited(with event: NSEvent) { updatePills() }
    override func mouseMoved(with event: NSEvent) { controller?.mouseMoved(to: NSEvent.mouseLocation) }
    override func mouseDown(with event: NSEvent) { controller?.mouseDown(at: NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) { controller?.mouseDragged(to: NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { controller?.mouseUp(at: NSEvent.mouseLocation) }
    override func rightMouseDown(with event: NSEvent) { controller?.cancel() }
    override func cancelOperation(_ sender: Any?) { controller?.cancel() }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case KeyCode.escape:
            controller?.cancel()
        case KeyCode.returnKey, KeyCode.keypadEnter, KeyCode.letterF:
            controller?.selectFullScreen()
        default:
            // Swallow other keys so the overlay never beeps.
            break
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Self.dimColor.setFill()
        bounds.fill()
        if let rect = state.dragRect {
            drawHighlight(local(rect))
        } else if let window = state.hovered {
            drawHighlight(local(window.frame))
        }
    }

    private func local(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY).intersection(bounds)
    }

    private func sizeLabel(for rect: CGRect) -> String {
        "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))"
    }

    private func drawHighlight(_ rect: CGRect) {
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        Self.accent.withAlphaComponent(0.08).setFill()
        rect.fill(using: .sourceOver)
        let border = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.setLineDash([6, 4], count: 2, phase: 0)
        Self.accent.setStroke()
        border.stroke()
    }

    // MARK: - Pills

    private func updatePills() {
        updateSizePill()
        if NSMouseInRect(NSEvent.mouseLocation, screenFrame, false) {
            hintPill.show(Self.hint, centeredAt: CGPoint(x: bounds.midX, y: bounds.maxY - Self.hintTopInset))
        } else {
            hintPill.hide()
        }
    }

    private func updateSizePill() {
        let text: String
        let rect: CGRect
        if let dragRect = state.dragRect {
            text = sizeLabel(for: dragRect)
            rect = local(dragRect)
        } else if let window = state.hovered {
            text = [window.appName, sizeLabel(for: window.frame)].compactMap(\.self).joined(separator: "  ")
            rect = local(window.frame)
        } else {
            sizePill.hide()
            return
        }
        guard !rect.isNull, rect.width > 0 else {
            sizePill.hide()
            return
        }
        sizePill.show(text, centeredAt: CGPoint(x: rect.midX, y: rect.midY), clampedTo: bounds)
    }
}
