import AppKit

/// A frozen snapshot of one display.
@MainActor
struct DisplaySnapshot {
    let screen: NSScreen
    /// Display frame in global AppKit points.
    let frame: CGRect
    let image: CGImage
    /// Image pixels per point.
    let scale: CGFloat
}

/// One display the user can select on. `snapshot` is nil for live (non-frozen) selection.
@MainActor
struct SelectionSurface {
    let screen: NSScreen
    let frame: CGRect
    let snapshot: DisplaySnapshot?

    init(snapshot: DisplaySnapshot) {
        screen = snapshot.screen
        frame = snapshot.frame
        self.snapshot = snapshot
    }

    init(liveScreen screen: NSScreen) {
        self.screen = screen
        frame = screen.frame
        snapshot = nil
    }
}

/// Outcome of the area selection overlay.
@MainActor
struct AreaSelection {
    /// Selected rect in global AppKit points, inside `surface.frame`.
    let rect: CGRect
    let surface: SelectionSurface
    /// Set when the user clicked a window / element instead of dragging.
    let window: WindowInfo?
}

/// A window paired with its frame converted to global AppKit coordinates.
struct LocatedWindow: Sendable {
    let info: WindowInfo
    let frame: CGRect

    @MainActor
    static func locate(_ windows: [WindowInfo]) -> [LocatedWindow] {
        let height = CoordinateSpace.primaryScreenHeight
        return windows.map {
            LocatedWindow(info: $0, frame: CoordinateSpace.appKitRect(fromQuartz: $0.quartzFrame, primaryHeight: height))
        }
    }
}

/// What the overlay views should render.
struct SelectionRenderState {
    var selection: CGRect?
    var highlight: CGRect?
    var cursor: CGPoint
    var isEditing: Bool
    var showsSizeLabel: Bool
    var showsMagnifier: Bool
}

/// Drives area selection: hover snapping, rubber-band creation, then an editable
/// selection (move, resize, nudge) confirmed with Return, double-click or the toolbar.
@MainActor
final class AreaSelectionController: OverlayInputDelegate {
    private enum Phase {
        case idle
        case creating(anchor: CGPoint, fromEditing: Bool)
        case editing
        case moving(start: CGPoint, original: CGRect)
        case resizing(SelectionHandle, start: CGPoint, original: CGRect)
    }

    private static let minimumDragDistance: CGFloat = 3

    private let surfaces: [SelectionSurface]
    private let windows: [LocatedWindow]
    private let showMagnifier: Bool
    private let presenter = OverlayPresenter()
    private let locator = ElementLocator()
    private var views: [AreaSelectionView] = []
    private var continuation: CheckedContinuation<AreaSelection?, Never>?

    private var phase: Phase = .idle
    private var selection: CGRect?
    private var surfaceIndex: Int?
    private var cursor: CGPoint = NSEvent.mouseLocation
    private var lastDragPoint: CGPoint = .zero
    private var isSquare = false
    private var isSpaceDown = false

    private var hoverWindow: LocatedWindow?
    private var hoverTargets: [CGRect] = []
    private var hoverIndex = 0

    init(surfaces: [SelectionSurface], windows: [LocatedWindow], showMagnifier: Bool) {
        self.surfaces = surfaces
        self.windows = windows
        self.showMagnifier = showMagnifier
    }

    /// Shows the overlays and suspends until the user confirms or cancels.
    func run() async -> AreaSelection? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            showOverlays()
        }
    }

    // MARK: - Mouse

    func overlayMouseDown(_ event: OverlayMouseEvent) {
        let point = event.location
        cursor = point
        lastDragPoint = point
        isSquare = event.modifiers.contains(.shift)
        guard case .editing = phase, let rect = selection else {
            beginCreating(at: point, fromEditing: false)
            return
        }
        if event.clickCount >= 2, rect.contains(point) {
            confirm()
        } else if let handle = SelectionGeometry.handle(at: point, in: rect) {
            phase = .resizing(handle, start: point, original: rect)
        } else if rect.contains(point) {
            phase = .moving(start: point, original: rect)
        } else {
            beginCreating(at: point, fromEditing: true)
        }
        refresh()
    }

    func overlayMouseDragged(_ event: OverlayMouseEvent) {
        let point = event.location
        let step = CGVector(dx: point.x - lastDragPoint.x, dy: point.y - lastDragPoint.y)
        lastDragPoint = point
        cursor = point
        isSquare = event.modifiers.contains(.shift)
        guard let bounds = activeBounds else { return }

        switch phase {
        case .creating(var anchor, let fromEditing):
            if isSpaceDown {
                anchor = CGPoint(x: anchor.x + step.dx, y: anchor.y + step.dy)
                phase = .creating(anchor: anchor, fromEditing: fromEditing)
            }
            selection = SelectionGeometry.spanning(anchor: anchor, cursor: point, square: isSquare, bounds: bounds)
        case let .moving(start, original):
            let delta = CGVector(dx: point.x - start.x, dy: point.y - start.y)
            selection = SelectionGeometry.move(original, by: delta, within: bounds)
        case let .resizing(handle, start, original):
            let delta = CGVector(dx: point.x - start.x, dy: point.y - start.y)
            selection = SelectionGeometry.resize(original, handle: handle, by: delta, within: bounds) ?? selection
        case .idle, .editing:
            break
        }
        refresh()
    }

    func overlayMouseUp(_ event: OverlayMouseEvent) {
        cursor = event.location
        switch phase {
        case let .creating(_, fromEditing):
            finishCreating(at: event.location, fromEditing: fromEditing)
        case .moving, .resizing:
            phase = .editing
        case .idle, .editing:
            break
        }
        refresh()
    }

    func overlayMouseMoved(to point: CGPoint) {
        cursor = point
        if case .idle = phase { updateHover(at: point) }
        refresh()
    }

    func overlayModifiersChanged(_ modifiers: NSEvent.ModifierFlags) {
        isSquare = modifiers.contains(.shift)
    }

    func overlayCursor(at point: CGPoint) -> NSCursor {
        switch phase {
        case .moving:
            return .closedHand
        case let .resizing(handle, _, _):
            return handle.cursor
        case .editing:
            guard let rect = selection else { return .crosshair }
            if let handle = SelectionGeometry.handle(at: point, in: rect) { return handle.cursor }
            return rect.contains(point) ? .openHand : .crosshair
        case .idle, .creating:
            return .crosshair
        }
    }

    func overlayCancel() {
        finish(nil)
    }

    // MARK: - Keyboard

    func overlayKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.escape:
            finish(nil)
        case KeyCode.returnKey, KeyCode.keypadEnter:
            if case .editing = phase { confirm() }
        case KeyCode.space:
            isSpaceDown = true
        case KeyCode.tab:
            cycleHoverTarget()
        case KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow:
            nudge(keyCode: event.keyCode, modifiers: event.modifierFlags)
        default:
            return false
        }
        return true
    }

    func overlayKeyUp(_ event: NSEvent) -> Bool {
        guard event.keyCode == KeyCode.space else { return false }
        isSpaceDown = false
        return true
    }

    // MARK: - Private: state changes

    private var activeBounds: CGRect? {
        surfaceIndex.map { surfaces[$0].frame }
    }

    private func beginCreating(at point: CGPoint, fromEditing: Bool) {
        surfaceIndex = surfaces.firstIndex { $0.frame.contains(point) } ?? (surfaces.isEmpty ? nil : 0)
        selection = nil
        phase = .creating(anchor: point, fromEditing: fromEditing)
        refresh()
    }

    private func finishCreating(at point: CGPoint, fromEditing: Bool) {
        if let rect = selection, rect.width >= Self.minimumDragDistance, rect.height >= Self.minimumDragDistance {
            phase = .editing
        } else if !fromEditing, let target = hoverSelection(at: point) {
            finish(target)
        } else {
            selection = nil
            phase = .idle
            updateHover(at: point)
        }
    }

    private func nudge(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        guard case .editing = phase, let rect = selection, let bounds = activeBounds else { return }
        let step: CGFloat = modifiers.contains(.shift) ? 10 : 1
        let dx: CGFloat = keyCode == KeyCode.leftArrow ? -step : (keyCode == KeyCode.rightArrow ? step : 0)
        let dy: CGFloat = keyCode == KeyCode.downArrow ? -step : (keyCode == KeyCode.upArrow ? step : 0)
        if modifiers.contains(.option) {
            // ⌥→ / ⌥↓ grow, ⌥← / ⌥↑ shrink; the top-left corner stays put.
            selection = SelectionGeometry.grow(rect, width: dx, height: -dy, within: bounds)
        } else {
            selection = SelectionGeometry.move(rect, by: CGVector(dx: dx, dy: dy), within: bounds)
        }
        refresh()
    }

    private func confirm() {
        guard let rect = selection, let index = surfaceIndex, rect.width >= 1, rect.height >= 1 else { return }
        finish(AreaSelection(rect: rect, surface: surfaces[index], window: nil))
    }

    // MARK: - Private: hover snapping

    private func updateHover(at point: CGPoint) {
        let window = windows.first { $0.frame.contains(point) }
        let targets = window.map { locator.targets(at: point, in: $0) } ?? []
        if targets != hoverTargets || window?.info != hoverWindow?.info {
            hoverIndex = 0
        }
        hoverWindow = window
        hoverTargets = targets
    }

    private func cycleHoverTarget() {
        guard case .idle = phase, !hoverTargets.isEmpty else { return }
        hoverIndex = (hoverIndex + 1) % hoverTargets.count
        refresh()
    }

    private var hoverRect: CGRect? {
        hoverTargets.indices.contains(hoverIndex) ? hoverTargets[hoverIndex] : nil
    }

    private func hoverSelection(at point: CGPoint) -> AreaSelection? {
        guard let target = hoverRect,
              let surface = surfaces.first(where: { $0.frame.contains(point) }),
              let rect = SelectionGeometry.clip(target, to: surface.frame),
              rect.width >= 1, rect.height >= 1 else { return nil }
        return AreaSelection(rect: rect, surface: surface, window: hoverWindow?.info)
    }

    // MARK: - Private: presentation

    private func showOverlays() {
        let pairs = surfaces.map { surface -> (OverlayWindow, AreaSelectionView) in
            let window = OverlayWindow(screen: surface.screen)
            let view = AreaSelectionView(surface: surface)
            view.inputDelegate = self
            view.onConfirm = { [weak self] in self?.confirm() }
            view.onCancel = { [weak self] in self?.finish(nil) }
            window.contentView = view
            return (window, view)
        }
        views = pairs.map(\.1)
        presenter.present(pairs.map(\.0), keyHandler: self)
        updateHover(at: cursor)
        refresh()
    }

    private func refresh() {
        let state = renderState
        views.forEach { $0.update(state: state) }
    }

    private var renderState: SelectionRenderState {
        var state = SelectionRenderState(
            selection: selection,
            highlight: nil,
            cursor: cursor,
            isEditing: false,
            showsSizeLabel: false,
            showsMagnifier: showMagnifier
        )
        switch phase {
        case .idle:
            state.highlight = hoverRect
        case .creating, .resizing:
            state.showsSizeLabel = selection != nil
        case .editing:
            state.isEditing = true
            state.showsMagnifier = false
        case .moving:
            state.showsMagnifier = false
        }
        return state
    }

    private func finish(_ result: AreaSelection?) {
        guard let continuation else { return }
        self.continuation = nil
        presenter.dismiss()
        views = []
        continuation.resume(returning: result)
    }
}
