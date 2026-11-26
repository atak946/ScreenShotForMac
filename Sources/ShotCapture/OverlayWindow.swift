import AppKit
import ShotCore

/// Borderless, full-screen window that floats above everything (including the menu bar)
/// on every Space and is unaffected by Mission Control.
@MainActor
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows a set of overlay windows, makes the one under the cursor key, routes keys to
/// the input delegate and hands focus back to the previously active app on dismissal.
@MainActor
final class OverlayPresenter {
    private var windows: [OverlayWindow] = []
    private var previousApp: NSRunningApplication?
    private let keyMonitor = KeyMonitor()

    func present(_ newWindows: [OverlayWindow], keyHandler: OverlayInputDelegate) {
        let current = NSRunningApplication.current
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.processIdentifier == current.processIdentifier ? nil : frontmost
        windows = newWindows

        keyMonitor.start { [weak keyHandler] event in
            guard let keyHandler else { return false }
            return event.type == .keyDown ? keyHandler.overlayKeyDown(event) : keyHandler.overlayKeyUp(event)
        }
        NSApp.activate()
        let mouse = NSEvent.mouseLocation
        let keyWindow = newWindows.first { $0.frame.contains(mouse) } ?? newWindows.first
        newWindows.forEach { $0.orderFrontRegardless() }
        keyWindow?.makeKeyAndOrderFront(nil)
        keyWindow?.makeFirstResponder(keyWindow?.contentView)
        NSCursor.crosshair.set()
        if keyWindow?.isKeyWindow == false {
            Log.capture.notice("Overlay could not become key; relying on key monitors")
        }
    }

    func dismiss() {
        keyMonitor.stop()
        windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        windows = []
        NSCursor.arrow.set()
        restoreFocus()
    }

    private func restoreFocus() {
        guard let app = previousApp, !app.isTerminated else { return }
        previousApp = nil
        NSApp.yieldActivation(to: app)
        app.activate()
    }
}

/// A mouse event normalized to global AppKit points.
struct OverlayMouseEvent {
    let location: CGPoint
    let modifiers: NSEvent.ModifierFlags
    let clickCount: Int
}

/// Receives normalized input from overlay views.
@MainActor
protocol OverlayInputDelegate: AnyObject {
    func overlayMouseDown(_ event: OverlayMouseEvent)
    func overlayMouseDragged(_ event: OverlayMouseEvent)
    func overlayMouseUp(_ event: OverlayMouseEvent)
    func overlayMouseMoved(to point: CGPoint)
    func overlayModifiersChanged(_ modifiers: NSEvent.ModifierFlags)
    /// Returns true when the key was consumed.
    func overlayKeyDown(_ event: NSEvent) -> Bool
    func overlayKeyUp(_ event: NSEvent) -> Bool
    func overlayCursor(at point: CGPoint) -> NSCursor
    func overlayCancel()
}

extension OverlayInputDelegate {
    func overlayKeyUp(_ event: NSEvent) -> Bool { false }
    func overlayCursor(at point: CGPoint) -> NSCursor { .crosshair }
    func overlayModifiersChanged(_ modifiers: NSEvent.ModifierFlags) {}
}

/// Base view for overlays: delegate-driven cursor, mouse tracking and right-click cancel.
/// Keys arrive through `OverlayPresenter`'s monitors.
@MainActor
class OverlayInputView: NSView {
    weak var inputDelegate: OverlayInputDelegate?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(event)
    }

    override func mouseMoved(with event: NSEvent) {
        inputDelegate?.overlayMouseMoved(to: NSEvent.mouseLocation)
        updateCursor(event)
    }

    override func mouseDown(with event: NSEvent) {
        inputDelegate?.overlayMouseDown(normalized(event))
        updateCursor(event)
    }

    override func mouseDragged(with event: NSEvent) {
        inputDelegate?.overlayMouseDragged(normalized(event))
    }

    override func mouseUp(with event: NSEvent) {
        inputDelegate?.overlayMouseUp(normalized(event))
        updateCursor(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        inputDelegate?.overlayCancel()
    }

    override func flagsChanged(with event: NSEvent) {
        inputDelegate?.overlayModifiersChanged(event.modifierFlags)
    }

    /// Keys are handled by the presenter's monitors; swallow leftovers so nothing beeps.
    override func keyDown(with event: NSEvent) {}

    override func cancelOperation(_ sender: Any?) {
        inputDelegate?.overlayCancel()
    }

    private func normalized(_ event: NSEvent) -> OverlayMouseEvent {
        OverlayMouseEvent(location: NSEvent.mouseLocation, modifiers: event.modifierFlags, clickCount: event.clickCount)
    }

    private func updateCursor(_ event: NSEvent) {
        // Interactive subviews (e.g. the selection toolbar) get the regular arrow.
        if let hit = hitTest(convert(event.locationInWindow, from: nil)), hit !== self {
            NSCursor.arrow.set()
            return
        }
        (inputDelegate?.overlayCursor(at: NSEvent.mouseLocation) ?? .crosshair).set()
    }
}
