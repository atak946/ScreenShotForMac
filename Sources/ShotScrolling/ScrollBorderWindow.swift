import AppKit
import ShotCore

/// Click-through window that outlines the capture area. The border is drawn outside the area
/// so it never appears in the frames (and our windows are excluded from capture anyway).
@MainActor
final class ScrollBorderWindow: NSWindow {
    private static let outset: CGFloat = 4

    init(area: CGRect) {
        let frame = area.insetBy(dx: -Self.outset, dy: -Self.outset)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        level = .statusBar
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = BorderView(frame: CGRect(origin: .zero, size: frame.size), outset: Self.outset)
    }
}

@MainActor
private final class BorderView: NSView {
    private let outset: CGFloat

    init(frame: CGRect, outset: CGFloat) {
        self.outset = outset
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: outset / 2, dy: outset / 2)
        let path = NSBezierPath(rect: rect)
        NSColor.white.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 2
        path.stroke()
        path.setLineDash([8, 5], count: 2, phase: 0)
        DS.Palette.accent.setStroke()
        path.stroke()
    }
}
