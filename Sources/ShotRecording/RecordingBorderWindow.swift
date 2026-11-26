import AppKit
import ShotCore

/// Click-through window drawing a thin dashed border around the recorded area.
/// It belongs to this app, so the capture filter excludes it.
@MainActor
final class RecordingBorderWindow {
    private static let outset: CGFloat = 4
    private let window: NSWindow

    init(target: RecordingTarget) {
        let outer = target.rect.insetBy(dx: -Self.outset, dy: -Self.outset).intersection(target.displayFrame)
        window = NSWindow(contentRect: outer, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = DashedBorderView(frame: CGRect(origin: .zero, size: outer.size))
    }

    func show() {
        window.orderFrontRegardless()
    }

    func close() {
        window.orderOut(nil)
    }
}

/// 2pt red dashes over a soft white under-stroke so the border reads on any content.
@MainActor
private final class DashedBorderView: NSView {
    private static let lineWidth: CGFloat = 2
    private static let dashPattern: [CGFloat] = [8, 5]

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: Self.lineWidth, dy: Self.lineWidth)
        let base = NSBezierPath(rect: rect)
        base.lineWidth = Self.lineWidth
        NSColor.white.withAlphaComponent(0.7).setStroke()
        base.stroke()

        let dashes = NSBezierPath(rect: rect)
        dashes.lineWidth = Self.lineWidth
        dashes.setLineDash(Self.dashPattern, count: Self.dashPattern.count, phase: 0)
        DS.Palette.recording.setStroke()
        dashes.stroke()
    }
}
