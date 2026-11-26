import AppKit

/// Receives input from the overlay windows.
@MainActor
protocol ColorPickerOverlayDelegate: AnyObject {
    func overlayMouseMoved()
    func overlayClicked()
    func overlayCancelled()
    func overlayKeyDown(_ event: NSEvent)
}

/// Borderless window covering one screen (menu bar included) on every space.
@MainActor
final class ColorPickerOverlayWindow: NSWindow {
    let overlayView: ColorPickerOverlayView
    weak var overlayDelegate: ColorPickerOverlayDelegate?

    init(screen: NSScreen, snapshot: CGImage) {
        overlayView = ColorPickerOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size), snapshot: snapshot)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        contentView = overlayView
        setFrame(screen.frame, display: false)
        overlayView.attach(to: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        overlayDelegate?.overlayKeyDown(event)
    }

    /// Prevents the system beep for unhandled key equivalents such as Tab.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        overlayDelegate?.overlayKeyDown(event)
        return true
    }
}

/// Shows the frozen snapshot and hosts the loupe.
@MainActor
final class ColorPickerOverlayView: NSView {
    private let loupe = LoupeView(frame: .zero)
    private weak var ownerWindow: ColorPickerOverlayWindow?
    private var trackingArea: NSTrackingArea?

    init(frame: CGRect, snapshot: CGImage) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contents = snapshot
        layer?.contentsGravity = .resize
        loupe.isHidden = true
        addSubview(loupe)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func attach(to owner: ColorPickerOverlayWindow) {
        ownerWindow = owner
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Positions the loupe so its grid is centered on `localPoint` (view coordinates).
    func showLoupe(_ content: LoupeContent, centeredAt localPoint: CGPoint) {
        let size = LoupeView.size(for: content.label)
        let origin = CGPoint(
            x: (localPoint.x - size.width / 2).rounded(),
            y: (localPoint.y - LoupeView.gridCenterOffsetY).rounded()
        )
        loupe.frame = CGRect(origin: origin, size: size)
        loupe.update(content)
        loupe.isHidden = false
    }

    func hideLoupe() {
        loupe.isHidden = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) { ownerWindow?.overlayDelegate?.overlayMouseMoved() }
    override func mouseEntered(with event: NSEvent) { ownerWindow?.overlayDelegate?.overlayMouseMoved() }
    override func mouseDragged(with event: NSEvent) { ownerWindow?.overlayDelegate?.overlayMouseMoved() }
    override func mouseDown(with event: NSEvent) { ownerWindow?.overlayDelegate?.overlayClicked() }
    override func rightMouseDown(with event: NSEvent) { ownerWindow?.overlayDelegate?.overlayCancelled() }
}
