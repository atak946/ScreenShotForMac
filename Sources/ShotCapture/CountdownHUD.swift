import AppKit
import ShotCore

/// Click-through countdown shown before a delayed capture. Draws an optional outline of
/// the area that will be captured and a large number centered in it (or on the screen).
@MainActor
final class CountdownHUD {
    private static let tick: Duration = .milliseconds(100)
    private static let ticksPerSecond = 10

    private let keyMonitor = KeyMonitor()
    private var isCancelled = false

    /// Counts down from `seconds`. Returns false when cancelled with Esc.
    func run(seconds: Int, area: CGRect?, on screen: NSScreen) async -> Bool {
        guard seconds > 0 else { return true }
        isCancelled = false
        let window = makeWindow(for: screen)
        let view = CountdownView(
            frame: CGRect(origin: .zero, size: screen.frame.size),
            area: area?.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        )
        window.contentView = view
        window.orderFrontRegardless()
        keyMonitor.start { [weak self] event in
            guard event.type == .keyDown, event.keyCode == KeyCode.escape else { return false }
            self?.isCancelled = true
            return true
        }
        defer {
            keyMonitor.stop()
            window.orderOut(nil)
            window.close()
        }

        for remaining in stride(from: seconds, to: 0, by: -1) {
            view.show(remaining)
            for _ in 0..<Self.ticksPerSecond {
                if isCancelled || Task.isCancelled { return false }
                try? await Task.sleep(for: Self.tick)
            }
        }
        return !isCancelled
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return window
    }
}

/// Draws the dashed capture outline and hosts the glass countdown badge.
@MainActor
private final class CountdownView: NSView {
    private static let edgeMargin: CGFloat = DS.Space.s

    private let area: CGRect?
    private let badge = CountdownBadgeView(ringColor: DS.Palette.accent)

    init(frame: CGRect, area: CGRect?) {
        self.area = area
        super.init(frame: frame)
        addSubview(badge)
        badge.setFrameOrigin(badgeOrigin)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show(_ number: Int) {
        badge.show(number)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let area { drawOutline(area) }
    }

    private var badgeOrigin: CGPoint {
        let target = area ?? bounds
        let side = CountdownBadgeView.side
        let half = side / 2 + Self.edgeMargin
        let x = min(max(target.midX, bounds.minX + half), bounds.maxX - half)
        let y = min(max(target.midY, bounds.minY + half), bounds.maxY - half)
        return CGPoint(x: x - side / 2, y: y - side / 2)
    }

    private func drawOutline(_ rect: CGRect) {
        let path = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
}
