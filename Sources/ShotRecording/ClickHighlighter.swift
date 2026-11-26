import AppKit
import QuartzCore
import ShotCore

/// Transparent click-through overlay over the recorded area that draws an expanding
/// circle on every left mouse down. Unlike the other recording windows it is
/// deliberately included in the capture.
@MainActor
final class ClickHighlighter {
    private static let diameter: CGFloat = 44
    private static let duration: CFTimeInterval = 0.45

    private let window: NSWindow
    private let rippleView: NSView
    private var monitors: [Any] = []

    init(rect: CGRect) {
        window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        rippleView = NSView(frame: CGRect(origin: .zero, size: rect.size))
        rippleView.wantsLayer = true
        window.contentView = rippleView
    }

    /// Window server ID, used to keep this window in the capture.
    var windowID: CGWindowID {
        CGWindowID(window.windowNumber)
    }

    func show() {
        window.orderFrontRegardless()
        let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated { self?.highlight(at: NSEvent.mouseLocation) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated { self?.highlight(at: NSEvent.mouseLocation) }
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        window.orderOut(nil)
    }

    private func highlight(at point: CGPoint) {
        guard window.frame.contains(point), let host = rippleView.layer else { return }
        let local = CGPoint(x: point.x - window.frame.minX, y: point.y - window.frame.minY)
        let ripple = makeRippleLayer(centeredAt: local)
        host.addSublayer(ripple)
        ripple.add(makeAnimation(), forKey: "ripple")
        Task { @MainActor in
            // Removal must happen even if the sleep is cancelled.
            try? await Task.sleep(for: .seconds(Self.duration))
            ripple.removeFromSuperlayer()
        }
    }

    private func makeRippleLayer(centeredAt center: CGPoint) -> CAShapeLayer {
        let side = Self.diameter
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.position = center
        layer.path = CGPath(ellipseIn: layer.bounds.insetBy(dx: 2, dy: 2), transform: nil)
        layer.fillColor = NSColor.systemYellow.withAlphaComponent(0.35).cgColor
        layer.strokeColor = NSColor.systemOrange.cgColor
        layer.lineWidth = 3
        layer.opacity = 0
        return layer
    }

    private func makeAnimation() -> CAAnimationGroup {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.3
        scale.toValue = 1.6
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.95
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return group
    }
}
