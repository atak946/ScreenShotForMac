import AppKit

/// Large glass circle with the remaining seconds and a ring that drains once per second.
@MainActor
public final class CountdownBadgeView: NSView {
    public static let side: CGFloat = 176
    private static let ringWidth: CGFloat = 4
    private static let ringInset: CGFloat = 8
    private static let tickDuration: CFTimeInterval = 1

    private let surface = GlassSurfaceView(cornerRadius: side / 2, forceDark: true)
    private let label = NSTextField(labelWithString: "")
    private let trackLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()

    public init(ringColor: NSColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        surface.frame = bounds
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
        configureLabel()
        configureRing(color: ringColor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows `number` with a short crossfade and restarts the one-second ring sweep.
    public func show(_ number: Int) {
        let fade = CATransition()
        fade.type = .fade
        fade.duration = DS.Motion.fast
        label.layer?.add(fade, forKey: "numberFade")
        label.stringValue = "\(number)"

        let sweep = CABasicAnimation(keyPath: "strokeEnd")
        sweep.fromValue = 1
        sweep.toValue = 0
        sweep.duration = Self.tickDuration
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        ringLayer.strokeEnd = 0
        ringLayer.add(sweep, forKey: "sweep")
    }

    private func configureLabel() {
        label.font = DS.Font.countdown
        label.textColor = .white
        label.alignment = .center
        label.wantsLayer = true
        label.translatesAutoresizingMaskIntoConstraints = false
        surface.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: surface.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
        ])
    }

    private func configureRing(color: NSColor) {
        let rect = bounds.insetBy(dx: Self.ringInset, dy: Self.ringInset)
        // Starts at 12 o'clock and runs clockwise (AppKit's y axis points up).
        let path = CGMutablePath()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - 2 * .pi,
            clockwise: true
        )
        for layer in [trackLayer, ringLayer] {
            layer.frame = bounds
            layer.path = path
            layer.fillColor = nil
            layer.lineWidth = Self.ringWidth
            layer.lineCap = .round
        }
        trackLayer.strokeColor = NSColor.white.withAlphaComponent(0.16).cgColor
        ringLayer.strokeColor = color.cgColor
        ringLayer.strokeEnd = 0
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(ringLayer)
    }
}
