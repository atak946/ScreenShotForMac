import AppKit
import QuartzCore
import ShotCore

@MainActor
protocol PinContentViewDelegate: AnyObject {
    func pinContentDidRequestClose()
    /// `zoomDelta` is multiplicative; `anchor` is in screen coordinates.
    func pinContentDidScroll(zoomDelta: CGFloat, anchor: CGPoint)
    func pinContentDidScrollOpacity(delta: CGFloat)
    func pinContentMenu() -> NSMenu
}

/// Draws the pinned image with a hairline border, a hover glass close button and a transient
/// glass HUD pill for zoom / opacity changes.
@MainActor
final class PinContentView: NSView {
    private enum Metrics {
        static let closeSize: CGFloat = 22
        static let closeSymbolSize: CGFloat = 10
        static let closeInset: CGFloat = DS.Space.s
        static let hudDuration: Duration = .milliseconds(900)
        static let preciseZoomStep: CGFloat = 0.01
        static let lineZoomStep: CGFloat = 0.1
        static let opacityStep: CGFloat = 0.005
        static let lineOpacityStep: CGFloat = 0.05
    }

    weak var delegate: PinContentViewDelegate?

    private let imageLayer = CALayer()
    private let closeChip = GlassSurfaceView(cornerRadius: Metrics.closeSize / 2, forceDark: true)
    private let hudPill = OverlayPill(font: DS.Font.numeric)
    private var hudTask: Task<Void, Never>?
    private var trackingArea: NSTrackingArea?
    private var isHoverEnabled = true
    private var isCloseVisible = false

    init(image: CGImage) {
        super.init(frame: .zero)
        wantsLayer = true
        configureLayers(image: image)
        configureCloseButton()
        configureHUD()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setImage(_ image: CGImage) {
        imageLayer.contents = image
    }

    func setHoverEnabled(_ enabled: Bool) {
        isHoverEnabled = enabled
        if !enabled {
            setCloseVisible(false)
        }
    }

    func showHUD(_ text: String) {
        hudPill.alphaValue = 1
        hudPill.show(text, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
        hudTask?.cancel()
        hudTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Metrics.hudDuration)
            guard !Task.isCancelled else { return }
            self?.fadeOutHUD()
        }
    }

    private func fadeOutHUD() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.normal
            hudPill.animator().alphaValue = 0
        }
    }

    /// Fades the close chip; it is hidden (not hit-testable) once faded out.
    private func setCloseVisible(_ visible: Bool) {
        isCloseVisible = visible
        if visible { closeChip.isHidden = false }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.fast
            closeChip.animator().alphaValue = visible ? 1 : 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isCloseVisible else { return }
                self.closeChip.isHidden = true
            }
        }
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
        closeChip.frame = CGRect(
            x: Metrics.closeInset,
            y: bounds.height - Metrics.closeInset - Metrics.closeSize,
            width: Metrics.closeSize,
            height: Metrics.closeSize
        )
        if !hudPill.isHidden {
            hudPill.setFrameOrigin(CGPoint(x: (bounds.width - hudPill.frame.width) / 2, y: (bounds.height - hudPill.frame.height) / 2))
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: Mouse

    override func mouseEntered(with event: NSEvent) {
        setCloseVisible(isHoverEnabled)
    }

    override func mouseExited(with event: NSEvent) {
        setCloseVisible(false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        if event.clickCount >= 2 {
            delegate?.pinContentDidRequestClose()
            return
        }
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = delegate?.pinContentMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }
        if event.modifierFlags.contains(.option) {
            let step = event.hasPreciseScrollingDeltas ? Metrics.opacityStep : Metrics.lineOpacityStep
            delegate?.pinContentDidScrollOpacity(delta: delta * step)
            return
        }
        let step = event.hasPreciseScrollingDeltas ? Metrics.preciseZoomStep : Metrics.lineZoomStep
        let factor = max(0.5, min(1.5, 1 + delta * step))
        delegate?.pinContentDidScroll(zoomDelta: factor, anchor: NSEvent.mouseLocation)
    }

    override func magnify(with event: NSEvent) {
        delegate?.pinContentDidScroll(zoomDelta: 1 + event.magnification, anchor: NSEvent.mouseLocation)
    }

    // MARK: Setup

    private func configureLayers(image: CGImage) {
        guard let layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.masksToBounds = true
        layer.borderWidth = DS.Size.hairline
        layer.borderColor = NSColor(white: 0.5, alpha: 0.45).cgColor
        imageLayer.contents = image
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .nearest
        imageLayer.minificationFilter = .trilinear
        layer.addSublayer(imageLayer)
        layer.zPosition = 0
    }

    private func configureCloseButton() {
        let button = IconButton(
            symbol: "xmark",
            tooltip: String(localized: "Close pin", bundle: .module),
            size: Metrics.closeSize,
            pointSize: Metrics.closeSymbolSize,
            target: self,
            action: #selector(closeClicked)
        )
        button.layer?.cornerRadius = Metrics.closeSize / 2
        button.translatesAutoresizingMaskIntoConstraints = true
        button.frame = CGRect(x: 0, y: 0, width: Metrics.closeSize, height: Metrics.closeSize)
        button.autoresizingMask = [.width, .height]
        closeChip.contentView.addSubview(button)
        closeChip.alphaValue = 0
        closeChip.isHidden = true
        addSubview(closeChip)
    }

    private func configureHUD() {
        addSubview(hudPill)
    }

    @objc
    private func closeClicked() {
        delegate?.pinContentDidRequestClose()
    }
}
