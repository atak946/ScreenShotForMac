import AppKit

/// Receives input from the measure overlay windows.
@MainActor
protocol MeasureOverlayDelegate: AnyObject {
    func overlayMouseMoved()
    func overlayMouseDown()
    func overlayMouseDragged()
    func overlayMouseUp()
    func overlayCancelled()
    func overlayKeyDown(_ event: NSEvent)
    func overlayModifiersChanged()
}

/// Borderless window covering one screen (menu bar included) on every space.
@MainActor
final class MeasureOverlayWindow: NSWindow {
    let measureView: MeasureView
    weak var overlayDelegate: MeasureOverlayDelegate?

    init(screen: NSScreen, snapshot: CGImage) {
        measureView = MeasureView(frame: CGRect(origin: .zero, size: screen.frame.size), snapshot: snapshot)
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
        contentView = measureView
        setFrame(screen.frame, display: false)
        measureView.attach(to: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        overlayDelegate?.overlayKeyDown(event)
    }

    override func flagsChanged(with event: NSEvent) {
        overlayDelegate?.overlayModifiersChanged()
    }

    /// Prevents the system beep for unhandled key equivalents such as Tab.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        overlayDelegate?.overlayKeyDown(event)
        return true
    }
}
