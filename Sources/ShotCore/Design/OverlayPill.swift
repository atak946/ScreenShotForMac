import AppKit

/// Small dark glass capsule with one line of text (sizes, coordinates, hints).
/// Frame-based so it can follow the cursor cheaply; ignores the mouse so the
/// overlay underneath keeps receiving events.
@MainActor
public final class OverlayPill: NSView {
    private static let horizontalPadding: CGFloat = DS.Space.s + DS.Space.xxs
    private static let minHeight: CGFloat = 22

    private let surface: GlassSurfaceView
    private let label = NSTextField(labelWithString: "")
    private let verticalPadding: CGFloat

    public init(font: NSFont = DS.Font.numeric, verticalPadding: CGFloat = DS.Space.xs) {
        self.verticalPadding = verticalPadding
        surface = GlassSurfaceView(cornerRadius: Self.minHeight / 2, forceDark: true)
        super.init(frame: .zero)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byClipping
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
        surface.contentView.addSubview(label)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Size the pill needs for `text`.
    public func fittingSize(for text: String) -> CGSize {
        label.stringValue = text
        let textSize = label.intrinsicContentSize
        return CGSize(
            width: ceil(textSize.width + Self.horizontalPadding * 2),
            height: max(Self.minHeight, ceil(textSize.height + verticalPadding * 2))
        )
    }

    /// Shows `text` with the pill's frame origin at `origin` (in the superview).
    public func show(_ text: String, origin: CGPoint) {
        let size = fittingSize(for: text)
        show(text, frame: CGRect(origin: origin, size: size))
    }

    /// Shows `text` centered on `center`, kept inside `bounds` of the superview.
    public func show(_ text: String, centeredAt center: CGPoint, clampedTo container: CGRect? = nil) {
        let size = fittingSize(for: text)
        var origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        if let container {
            origin.x = min(max(origin.x, container.minX), container.maxX - size.width)
            origin.y = min(max(origin.y, container.minY), container.maxY - size.height)
        }
        show(text, frame: CGRect(origin: origin, size: size))
    }

    public func hide() {
        isHidden = true
    }

    private func show(_ text: String, frame newFrame: CGRect) {
        label.stringValue = text
        let rounded = newFrame.integral
        if frame != rounded { frame = rounded }
        surface.cornerRadius = rounded.height / 2
        let textHeight = label.intrinsicContentSize.height
        label.frame = CGRect(
            x: 0,
            y: ((rounded.height - textHeight) / 2).rounded(),
            width: rounded.width,
            height: textHeight
        )
        isHidden = false
    }
}
