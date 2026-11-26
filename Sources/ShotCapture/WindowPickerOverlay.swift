import AppKit
import ShotCore

/// Transparent overlay that highlights the window under the cursor; a click picks it.
@MainActor
final class WindowPickerController: OverlayInputDelegate {
    private let windows: [LocatedWindow]
    private let presenter = OverlayPresenter()
    private var views: [WindowPickerView] = []
    private var continuation: CheckedContinuation<LocatedWindow?, Never>?
    private var hovered: LocatedWindow?

    init(windows: [LocatedWindow]) {
        self.windows = windows
    }

    /// Shows the overlays and suspends until a window is clicked or the user cancels.
    func run() async -> LocatedWindow? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            showOverlays()
        }
    }

    // MARK: - OverlayInputDelegate

    func overlayMouseDown(_ event: OverlayMouseEvent) {
        updateHover(at: event.location)
    }

    func overlayMouseDragged(_ event: OverlayMouseEvent) {
        updateHover(at: event.location)
    }

    func overlayMouseUp(_ event: OverlayMouseEvent) {
        updateHover(at: event.location)
        guard let hovered else { return }
        finish(hovered)
    }

    func overlayMouseMoved(to point: CGPoint) {
        updateHover(at: point)
    }

    func overlayKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.escape:
            finish(nil)
        case KeyCode.returnKey, KeyCode.keypadEnter:
            if let hovered { finish(hovered) }
        default:
            return false
        }
        return true
    }

    func overlayCancel() {
        finish(nil)
    }

    // MARK: - Private

    private func showOverlays() {
        let pairs = NSScreen.screens.map { screen -> (OverlayWindow, WindowPickerView) in
            let window = OverlayWindow(screen: screen)
            let view = WindowPickerView(screenFrame: screen.frame)
            view.inputDelegate = self
            window.contentView = view
            return (window, view)
        }
        views = pairs.map(\.1)
        presenter.present(pairs.map(\.0), keyHandler: self)
        updateHover(at: NSEvent.mouseLocation, force: true)
    }

    private func updateHover(at point: CGPoint, force: Bool = false) {
        let candidate = windows.first { $0.frame.contains(point) }
        guard force || candidate?.info != hovered?.info else { return }
        hovered = candidate
        views.forEach { $0.update(highlight: candidate) }
    }

    private func finish(_ result: LocatedWindow?) {
        guard let continuation else { return }
        self.continuation = nil
        presenter.dismiss()
        views = []
        continuation.resume(returning: result)
    }
}

/// Draws the hover highlight (accent tint + 2pt accent border) and a glass pill with the
/// owning app's name and size for one display.
@MainActor
final class WindowPickerView: OverlayInputView {
    private let screenFrame: CGRect
    private var highlight: LocatedWindow?
    private let namePill = OverlayPill(font: DS.Font.label, verticalPadding: DS.Space.s - DS.Space.xxs)

    /// Nearly transparent fill so the window server routes clicks to the overlay.
    private static let eventCatcherColor = NSColor.black.withAlphaComponent(0.01)
    private static let highlightFillAlpha: CGFloat = 0.15
    private static let borderWidth: CGFloat = 2

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        addSubview(namePill)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func update(highlight: LocatedWindow?) {
        self.highlight = highlight
        needsDisplay = true
        updatePill()
    }

    private var visibleHighlight: CGRect? {
        guard let highlight else { return nil }
        let local = highlight.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        let visible = local.intersection(bounds)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
        return visible
    }

    override func draw(_ dirtyRect: NSRect) {
        Self.eventCatcherColor.setFill()
        bounds.fill()
        guard let visible = visibleHighlight else { return }
        DS.Palette.accent.withAlphaComponent(Self.highlightFillAlpha).setFill()
        visible.fill(using: .sourceOver)
        let border = NSBezierPath(rect: visible.insetBy(dx: Self.borderWidth / 2, dy: Self.borderWidth / 2))
        border.lineWidth = Self.borderWidth
        DS.Palette.accent.setStroke()
        border.stroke()
    }

    private func updatePill() {
        guard let visible = visibleHighlight, let name = highlight?.info.appName, !name.isEmpty else {
            namePill.hide()
            return
        }
        let size = "\(Int(visible.width.rounded())) × \(Int(visible.height.rounded()))"
        namePill.show("\(name)  \(size)", centeredAt: CGPoint(x: visible.midX, y: visible.midY), clampedTo: bounds)
    }
}
