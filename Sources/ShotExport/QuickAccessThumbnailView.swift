import AppKit
import ShotCore

@MainActor
protocol QuickAccessThumbnailDelegate: AnyObject {
    func thumbnail(didRequest action: QuickAccessAction)
    func thumbnail(hoverChanged isHovering: Bool)
    func thumbnailFileURLForDrag() -> URL?
    func thumbnail(didEndFileDrag succeeded: Bool)
    func thumbnail(swipedBy offset: CGFloat)
    func thumbnail(didEndSwipe offset: CGFloat)
}

/// Rounded card (hairline + soft shadow) with a hover overlay and subtle hover scale,
/// double-click to edit, file drag and swipe-to-dismiss.
///
/// The view is `inset` larger than the card on every side so the shadow and hover scale
/// are not clipped by the panel.
@MainActor
final class QuickAccessThumbnailView: NSView, NSDraggingSource {
    private enum Gesture { case undecided, swipe, fileDrag }
    private static let dragThreshold: CGFloat = 5
    private static let hoverScale: CGFloat = 1.025
    /// Room around the card for its shadow and hover scale.
    static let inset: CGFloat = DS.Space.l

    weak var delegate: QuickAccessThumbnailDelegate?

    private let image: CGImage
    private let card = NSView()
    private let imageLayer = CALayer()
    private let overlay: QuickAccessOverlay
    private var mouseDownPoint: NSPoint?
    private var gesture: Gesture = .undecided
    private var trackingArea: NSTrackingArea?

    init(image: CGImage, showsPin: Bool, showsUpload: Bool = false) {
        self.image = image
        overlay = QuickAccessOverlay(showsPin: showsPin, showsUpload: showsUpload)
        super.init(frame: .zero)
        wantsLayer = true
        overlay.onAction = { [weak self] action in self?.delegate?.thumbnail(didRequest: action) }
        configureCard()
        configureOverlay()
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Screenshot preview", bundle: .module))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func configureCard() {
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        pin(card, to: self, inset: Self.inset)
        guard let root = card.layer else { return }
        root.cornerRadius = DS.Radius.card
        root.cornerCurve = .continuous
        root.masksToBounds = true
        root.backgroundColor = DS.Palette.canvas.cgColor
        root.borderWidth = DS.Size.hairline
        root.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        imageLayer.contents = image
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.minificationFilter = .trilinear
        root.addSublayer(imageLayer)

        // The shadow lives on our own (unclipped) layer, following the card's rounded rect.
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 10
        layer?.shadowOffset = CGSize(width: 0, height: -3)
    }

    private func configureOverlay() {
        overlay.alphaValue = 0
        overlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(overlay)
        pin(overlay, to: card, inset: 0)
    }

    private func pin(_ view: NSView, to container: NSView, inset: CGFloat) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = card.bounds
        layer?.shadowPath = CGPath(
            roundedRect: card.frame,
            cornerWidth: DS.Radius.card,
            cornerHeight: DS.Radius.card,
            transform: nil
        )
        CATransaction.commit()
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { setHovering(true) }
    override func mouseExited(with event: NSEvent) { setHovering(false) }

    private func setHovering(_ hovering: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.fast
            overlay.animator().alphaValue = hovering ? 1 : 0
        }
        applyScale(hovering ? Self.hoverScale : 1)
        delegate?.thumbnail(hoverChanged: hovering)
    }

    /// Scales the card (and its shadow) around the view center via `sublayerTransform`.
    private func applyScale(_ scale: CGFloat) {
        guard let layer else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var transform = CATransform3DMakeTranslation(center.x, center.y, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DTranslate(transform, -center.x, -center.y, 0)
        let animation = CABasicAnimation(keyPath: "sublayerTransform")
        animation.fromValue = layer.presentation()?.sublayerTransform ?? layer.sublayerTransform
        animation.toValue = transform
        animation.duration = DS.Motion.normal
        animation.timingFunction = DS.Motion.easeOut
        layer.sublayerTransform = transform
        layer.add(animation, forKey: "hoverScale")
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            mouseDownPoint = nil
            delegate?.thumbnail(didRequest: .edit)
            return
        }
        // Screen coordinates: the panel itself moves while swiping.
        mouseDownPoint = NSEvent.mouseLocation
        gesture = .undecided
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screenStart = mouseDownPoint else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - screenStart.x
        let dy = current.y - screenStart.y
        if gesture == .undecided {
            guard hypot(dx, dy) >= Self.dragThreshold else { return }
            gesture = (dx < 0 && abs(dx) > abs(dy) * 2) ? .swipe : .fileDrag
            if gesture == .fileDrag { beginFileDrag(with: event) }
        }
        if gesture == .swipe { delegate?.thumbnail(swipedBy: min(0, dx)) }
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownPoint = nil
            gesture = .undecided
        }
        guard gesture == .swipe, let screenStart = mouseDownPoint else { return }
        delegate?.thumbnail(didEndSwipe: min(0, NSEvent.mouseLocation.x - screenStart.x))
    }

    // MARK: File drag

    private func beginFileDrag(with event: NSEvent) {
        guard let url = delegate?.thumbnailFileURLForDrag() else {
            gesture = .undecided
            mouseDownPoint = nil
            return
        }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let preview = NSImage(cgImage: image, size: card.frame.size)
        item.setDraggingFrame(card.frame, contents: preview)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        mouseDownPoint = nil
        gesture = .undecided
        delegate?.thumbnail(didEndFileDrag: !operation.isEmpty)
    }
}
