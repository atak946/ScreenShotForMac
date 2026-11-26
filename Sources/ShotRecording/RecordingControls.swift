import AppKit
import ShotCore

/// Callbacks fired by the recording controls.
struct RecordingControlActions {
    let onStop: @MainActor () -> Void
    let onTogglePause: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
}

/// Small floating glass control capsule. The App's own menu bar item shows the
/// recording state and Stop, so this module adds no status item of its own.
@MainActor
final class RecordingControls {
    private let panel: RecordingControlPanel

    init(actions: RecordingControlActions) {
        panel = RecordingControlPanel(actions: actions)
    }

    func show(around target: RecordingTarget) {
        panel.show(around: target.rect, in: target.displayFrame)
    }

    func update(elapsed: TimeInterval, isPaused: Bool) {
        let time = RecordingGeometry.formatElapsed(elapsed)
        panel.update(time: time, isPaused: isPaused)
    }

    func close() {
        panel.close()
    }
}

/// Non-activating, draggable glass capsule: pulsing dot, elapsed time, pause / resume, stop, discard.
@MainActor
private final class RecordingControlPanel {
    private static let height: CGFloat = DS.Size.toolbarHeight
    private static let gap: CGFloat = DS.Space.m
    private static let fallbackBottomInset: CGFloat = 60
    private static let timeMinWidth: CGFloat = 46

    private let panel: NSPanel
    private let dot = RecordingDot()
    private let timeLabel = NSTextField(labelWithString: "0:00")
    private let pauseButton: IconButton
    private let targets: [ClosureActionTarget]

    init(actions: RecordingControlActions) {
        let pauseTarget = ClosureActionTarget(actions.onTogglePause)
        let stopTarget = ClosureActionTarget(actions.onStop)
        let cancelTarget = ClosureActionTarget(actions.onCancel)
        targets = [pauseTarget, stopTarget, cancelTarget]
        pauseButton = Self.makeButton("pause.fill", String(localized: "Pause", bundle: .module), pauseTarget)
        let stopButton = Self.makeButton("stop.fill", String(localized: "Stop and Save", bundle: .module), stopTarget)
        stopButton.tint = DS.Palette.recording
        let cancelButton = Self.makeButton("trash", String(localized: "Discard Recording", bundle: .module), cancelTarget)

        let content = Self.makeContent(dot: dot, time: timeLabel, buttons: [pauseButton, stopButton, cancelButton])
        let size = CGSize(width: ceil(content.fittingSize.width), height: Self.height)
        panel = FloatingPanel.make(size: size, level: .statusBar)
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior.insert(.stationary)
        content.frame = CGRect(origin: .zero, size: size)
        panel.contentView = content
    }

    func show(around rect: CGRect, in display: CGRect) {
        panel.setFrameOrigin(origin(around: rect, in: display))
        panel.orderFrontRegardless()
        dot.isPulsing = true
    }

    func close() {
        dot.isPulsing = false
        panel.orderOut(nil)
    }

    func update(time: String, isPaused: Bool) {
        timeLabel.stringValue = time
        timeLabel.textColor = isPaused ? .secondaryLabelColor : .labelColor
        dot.isPulsing = !isPaused
        let symbol = isPaused ? "play.fill" : "pause.fill"
        let title = isPaused ? String(localized: "Resume", bundle: .module) : String(localized: "Pause", bundle: .module)
        pauseButton.setSymbol(symbol, tooltip: title)
    }

    /// Below the recorded rect, else above it, else inside the bottom of the display.
    private func origin(around rect: CGRect, in display: CGRect) -> CGPoint {
        let size = panel.frame.size
        let x = min(max(rect.midX - size.width / 2, display.minX + Self.gap), display.maxX - size.width - Self.gap)
        let below = rect.minY - Self.gap - size.height
        let above = rect.maxY + Self.gap
        if below >= display.minY + Self.gap { return CGPoint(x: x, y: below) }
        if above + size.height <= display.maxY - Self.gap { return CGPoint(x: x, y: above) }
        return CGPoint(x: x, y: display.minY + Self.fallbackBottomInset)
    }

    private static func makeContent(dot: NSView, time: NSTextField, buttons: [NSView]) -> NSView {
        time.font = DS.Font.numericLarge
        time.textColor = .labelColor
        time.alignment = .left

        let divider = NSBox()
        divider.boxType = .separator

        let stack = NSStackView(views: [dot, time, divider] + buttons)
        stack.orientation = .horizontal
        stack.spacing = DS.Space.xs
        stack.setCustomSpacing(DS.Space.s, after: dot)
        stack.setCustomSpacing(DS.Space.s, after: time)
        stack.setCustomSpacing(DS.Space.s, after: divider)
        stack.edgeInsets = NSEdgeInsets(top: 0, left: DS.Space.l, bottom: 0, right: DS.Space.s)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let surface = GlassSurfaceView(cornerRadius: height / 2)
        surface.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            surface.heightAnchor.constraint(equalToConstant: height),
            stack.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
            time.widthAnchor.constraint(greaterThanOrEqualToConstant: timeMinWidth),
            divider.heightAnchor.constraint(equalToConstant: 18),
        ])
        return surface
    }

    private static func makeButton(_ symbol: String, _ tooltip: String, _ target: ClosureActionTarget) -> IconButton {
        IconButton(symbol: symbol, tooltip: tooltip, target: target, action: #selector(ClosureActionTarget.perform(_:)))
    }
}

/// Red recording dot that softly pulses while recording and rests (dimmed) while paused.
@MainActor
private final class RecordingDot: NSView {
    private static let diameter: CGFloat = 10
    private static let pulseKey = "pulse"

    var isPulsing = false {
        didSet {
            guard isPulsing != oldValue else { return }
            if isPulsing { startPulse() } else { stopPulse() }
        }
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter))
        wantsLayer = true
        layer?.backgroundColor = DS.Palette.recording.cgColor
        layer?.cornerRadius = Self.diameter / 2
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func startPulse() {
        layer?.opacity = 1
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.35
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(pulse, forKey: Self.pulseKey)
    }

    private func stopPulse() {
        layer?.removeAnimation(forKey: Self.pulseKey)
        layer?.opacity = 0.45
    }
}
