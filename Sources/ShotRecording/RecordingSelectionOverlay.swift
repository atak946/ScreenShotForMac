import AppKit
import CoreGraphics

/// An on-screen window of another app that can be picked for recording.
struct PickableWindow: Sendable, Equatable {
    let windowID: CGWindowID
    /// Frame in global AppKit points.
    let frame: CGRect
    let appName: String?

    /// Normal on-screen windows of other apps, front-most first.
    @MainActor
    static func onScreen() -> [PickableWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let height = RecordingGeometry.primaryScreenHeight
        return list.compactMap { entry -> PickableWindow? in
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let number = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 1, bounds.height > 1 else { return nil }
            let alpha = (entry[kCGWindowAlpha as String] as? Double) ?? 1
            guard alpha > 0 else { return nil }
            return PickableWindow(
                windowID: number,
                frame: RecordingGeometry.appKitRect(fromQuartz: bounds, primaryHeight: height),
                appName: entry[kCGWindowOwnerName as String] as? String
            )
        }
    }
}

/// Selection state rendered by every overlay view.
struct RecordingSelectionState: Equatable {
    var dragRect: CGRect?
    var hovered: PickableWindow?
}

/// Overlay that lets the user drag an area, click a window, or press F / Enter for the
/// full screen under the cursor. Esc or right click cancels.
@MainActor
final class RecordingSelectionController {
    private static let minimumDragDistance: CGFloat = 3

    private let candidates = PickableWindow.onScreen()
    private var overlayWindows: [NSWindow] = []
    private var views: [RecordingSelectionView] = []
    private var continuation: CheckedContinuation<RecordingTarget?, Never>?
    private var previousApp: NSRunningApplication?
    private var anchor: CGPoint?
    private var state = RecordingSelectionState()
    private let toolbar: RecordingOptionsToolbar?

    /// `toolbar` (optional) floats above the overlay so options can be flipped before picking.
    init(toolbar: RecordingOptionsToolbar? = nil) {
        self.toolbar = toolbar
    }

    /// Shows the overlays and suspends until the user picks a target or cancels.
    func run() async -> RecordingTarget? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    // MARK: - Input

    func mouseDown(at point: CGPoint) {
        anchor = point
        state.dragRect = nil
        render()
    }

    func mouseDragged(to point: CGPoint) {
        guard let anchor else { return }
        let distance = hypot(point.x - anchor.x, point.y - anchor.y)
        guard state.dragRect != nil || distance >= Self.minimumDragDistance else { return }
        let screenFrame = screen(containing: anchor)?.frame ?? .null
        state.dragRect = CGRect(spanning: anchor, point).intersection(screenFrame)
        state.hovered = nil
        render()
    }

    func mouseUp(at point: CGPoint) {
        defer { anchor = nil }
        if let rect = state.dragRect, let screen = screen(containing: anchor ?? point) {
            if let target = RecordingTarget.make(kind: .area, rect: rect, screen: screen) {
                finish(target)
            } else {
                state.dragRect = nil
                render()
            }
            return
        }
        pickWindowOrScreen(at: point)
    }

    func mouseMoved(to point: CGPoint) {
        guard anchor == nil else { return }
        let hovered = candidates.first { $0.frame.contains(point) }
        guard hovered != state.hovered else { return }
        state.hovered = hovered
        render()
    }

    func selectFullScreen() {
        guard let screen = NSScreen.underCursor else { return finish(nil) }
        finish(RecordingTarget.make(kind: .display, rect: screen.frame, screen: screen))
    }

    func cancel() {
        finish(nil)
    }

    // MARK: - Private

    private func pickWindowOrScreen(at point: CGPoint) {
        guard let window = candidates.first(where: { $0.frame.contains(point) }) else {
            // A click on the bare desktop records the whole screen it landed on.
            guard let screen = screen(containing: point) else { return }
            return finish(RecordingTarget.make(kind: .display, rect: screen.frame, screen: screen))
        }
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        guard let screen = screen(containing: center) ?? screen(containing: point) else { return }
        finish(RecordingTarget.make(kind: .window(window.windowID), rect: window.frame, screen: screen))
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func present() {
        let current = NSRunningApplication.current
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.processIdentifier == current.processIdentifier ? nil : frontmost

        for screen in NSScreen.screens {
            let window = SelectionOverlayWindow(screen: screen)
            let view = RecordingSelectionView(screenFrame: screen.frame, controller: self)
            window.contentView = view
            overlayWindows.append(window)
            views.append(view)
        }
        NSApp.activate()
        overlayWindows.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        let key = overlayWindows.first { $0.frame.contains(mouse) } ?? overlayWindows.first
        key?.makeKeyAndOrderFront(nil)
        key?.makeFirstResponder(key?.contentView)
        if let screen = screen(containing: mouse) ?? NSScreen.main {
            toolbar?.show(on: screen.frame)
        }
        NSCursor.crosshair.set()
        mouseMoved(to: mouse)
        render()
    }

    private func render() {
        views.forEach { $0.update(state) }
    }

    private func finish(_ target: RecordingTarget?) {
        guard let continuation else { return }
        self.continuation = nil
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = []
        toolbar?.close()
        views = []
        NSCursor.arrow.set()
        if let app = previousApp, !app.isTerminated {
            NSApp.yieldActivation(to: app)
            app.activate()
        }
        previousApp = nil
        continuation.resume(returning: target)
    }
}

/// Borderless full-screen window floating above everything on every Space.
@MainActor
private final class SelectionOverlayWindow: NSWindow {
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
