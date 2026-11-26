import AppKit
import ShotCore

/// The area the user picked for scrolling capture.
@MainActor
struct ScrollSelection {
    /// Selected rect in global AppKit points, inside `screen.frame`.
    let rect: CGRect
    let screen: NSScreen

    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    /// Selection in display-local points, top-left origin (ScreenCaptureKit `sourceRect`).
    var displayLocalRect: CGRect {
        let frame = screen.frame
        return CGRect(
            x: rect.minX - frame.minX,
            y: frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

/// Live (not frozen) drag-to-select overlay. Windows are translucent so content stays visible;
/// they are removed right after selection so the content can be scrolled.
@MainActor
final class ScrollAreaSelector {
    private static let minimumSide: CGFloat = 40

    private var windows: [SelectorWindow] = []
    private var views: [SelectorView] = []
    private var continuation: CheckedContinuation<ScrollSelection?, Never>?
    private var previousApp: NSRunningApplication?
    private var anchor: CGPoint?
    private var anchorScreen: NSScreen?
    private var cursor: CGPoint = .zero

    func run() async -> ScrollSelection? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    // MARK: - Input

    fileprivate func mouseDown(at point: CGPoint) {
        anchor = point
        cursor = point
        anchorScreen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
        refresh()
    }

    fileprivate func mouseDragged(to point: CGPoint) {
        cursor = point
        refresh()
    }

    fileprivate func mouseUp(at point: CGPoint) {
        cursor = point
        if let rect = selectionRect, let screen = anchorScreen,
           rect.width >= Self.minimumSide, rect.height >= Self.minimumSide {
            finish(ScrollSelection(rect: rect.integral, screen: screen))
            return
        }
        anchor = nil
        anchorScreen = nil
        refresh()
    }

    fileprivate func cancel() {
        finish(nil)
    }

    // MARK: - Private

    private var selectionRect: CGRect? {
        guard let anchor, let screen = anchorScreen else { return nil }
        let rect = CGRect(
            x: min(anchor.x, cursor.x), y: min(anchor.y, cursor.y),
            width: abs(anchor.x - cursor.x), height: abs(anchor.y - cursor.y)
        ).intersection(screen.frame)
        return rect.isNull ? nil : rect
    }

    private func present() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let isSelf = frontmost?.processIdentifier == NSRunningApplication.current.processIdentifier
        previousApp = isSelf ? nil : frontmost
        for screen in NSScreen.screens {
            let window = SelectorWindow(screen: screen)
            let view = SelectorView(screenFrame: screen.frame, selector: self)
            window.contentView = view
            windows.append(window)
            views.append(view)
        }
        NSApp.activate()
        let mouse = NSEvent.mouseLocation
        windows.forEach { $0.orderFrontRegardless() }
        let key = windows.first { $0.frame.contains(mouse) } ?? windows.first
        key?.makeKeyAndOrderFront(nil)
        key?.makeFirstResponder(key?.contentView)
        NSCursor.crosshair.set()
        refresh()
    }

    private func finish(_ result: ScrollSelection?) {
        guard let continuation else { return }
        self.continuation = nil
        windows.forEach { $0.orderOut(nil)
            $0.close()
        }
        windows = []
        views = []
        NSCursor.arrow.set()
        if let app = previousApp, !app.isTerminated {
            NSApp.yieldActivation(to: app)
            app.activate()
        }
        previousApp = nil
        continuation.resume(returning: result)
    }

    private func refresh() {
        let selection = selectionRect
        views.forEach { $0.update(selection: selection) }
    }
}

// MARK: - Window

@MainActor
private final class SelectorWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - View

@MainActor
private final class SelectorView: NSView {
    private static let escapeKeyCode: UInt16 = 53
    private static let hint = String(localized: "Drag to select the area to scroll · Esc to cancel", bundle: .module)
    private static let sizePillGap: CGFloat = DS.Space.s

    private let screenFrame: CGRect
    private weak var selector: ScrollAreaSelector?
    private var selection: CGRect?
    private let hintPill = OverlayPill(font: DS.Font.label, verticalPadding: DS.Space.s)
    private let sizePill = OverlayPill()

    init(screenFrame: CGRect, selector: ScrollAreaSelector) {
        self.screenFrame = screenFrame
        self.selector = selector
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        addSubview(hintPill)
        addSubview(sizePill)
        updatePills()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    func update(selection global: CGRect?) {
        selection = global.map { $0.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY) }
        needsDisplay = true
        updatePills()
    }

    override func mouseDown(with event: NSEvent) { selector?.mouseDown(at: NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) { selector?.mouseDragged(to: NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { selector?.mouseUp(at: NSEvent.mouseLocation) }
    override func rightMouseDown(with event: NSEvent) { selector?.cancel() }
    override func cancelOperation(_ sender: Any?) { selector?.cancel() }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == Self.escapeKeyCode else { return }
        selector?.cancel()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds)
        if let selection {
            path.append(NSBezierPath(rect: selection))
            path.windingRule = .evenOdd
        }
        DS.Palette.overlayDim.setFill()
        path.fill()
        if let selection { drawBorder(selection) }
    }

    /// 1pt white line with a soft dark halo, matching the screenshot selection.
    private func drawBorder(_ rect: CGRect) {
        let outer = NSBezierPath(rect: rect.insetBy(dx: -1.5, dy: -1.5))
        outer.lineWidth = 1
        NSColor.black.withAlphaComponent(0.35).setStroke()
        outer.stroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        DS.Palette.selection.setStroke()
        border.stroke()
    }

    private func updatePills() {
        guard let selection else {
            sizePill.hide()
            hintPill.show(Self.hint, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
            return
        }
        hintPill.hide()
        let text = "\(Int(selection.width)) × \(Int(selection.height))"
        let height = sizePill.fittingSize(for: text).height
        let center = CGPoint(x: selection.midX, y: selection.maxY + Self.sizePillGap + height / 2)
        sizePill.show(text, centeredAt: center, clampedTo: bounds.insetBy(dx: DS.Space.xs, dy: DS.Space.xs))
    }
}
