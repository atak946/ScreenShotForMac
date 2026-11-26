import AppKit
import ShotCore

/// Glass capsule shown next to an editable selection: its size, a cancel button and the
/// accent Capture pill. Every control accepts the first click.
@MainActor
final class SelectionToolbar: NSView {
    private static let height: CGFloat = 40
    private static let pillHeight: CGFloat = 28

    var onCapture: (() -> Void)?
    var onCancel: (() -> Void)?
    var onQuickAction: ((ExportAction) -> Void)?

    private let surface = GlassSurfaceView(cornerRadius: height / 2, forceDark: true)
    private let sizeLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        sizeLabel.font = DS.Font.numeric
        sizeLabel.textColor = .labelColor

        let cancel = IconButton(
            symbol: "xmark",
            tooltip: String(localized: "Cancel (Esc)", bundle: .module),
            target: self,
            action: #selector(cancelClicked)
        )
        let capture = AccentPillButton(
            title: String(localized: "Capture ↩", bundle: .module),
            height: Self.pillHeight,
            target: self,
            action: #selector(captureClicked)
        )
        capture.toolTip = String(localized: "Capture the selection (Return)", bundle: .module)
        let copy = IconButton(
            symbol: "doc.on.doc",
            tooltip: String(localized: "Copy to Clipboard (⌘C)", bundle: .module),
            target: self,
            action: #selector(copyClicked)
        )
        let save = IconButton(
            symbol: "square.and.arrow.down",
            tooltip: String(localized: "Save to File (⌘S)", bundle: .module),
            target: self,
            action: #selector(saveClicked)
        )

        let stack = NSStackView(views: [sizeLabel, cancel, copy, save, capture])
        stack.orientation = .horizontal
        stack.spacing = DS.Space.xs
        stack.setCustomSpacing(DS.Space.s, after: sizeLabel)
        stack.edgeInsets = NSEdgeInsets(top: 0, left: DS.Space.m + DS.Space.xxs, bottom: 0, right: DS.Space.s - DS.Space.xxs)
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        surface.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            surface.heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    func setSize(_ size: CGSize) {
        sizeLabel.stringValue = "\(Int(size.width.rounded())) × \(Int(size.height.rounded()))"
    }

    @objc
    private func captureClicked() {
        onCapture?()
    }

    @objc
    private func copyClicked() {
        onQuickAction?(.copy)
    }

    @objc
    private func saveClicked() {
        onQuickAction?(.save)
    }

    @objc
    private func cancelClicked() {
        onCancel?()
    }
}

/// Prominent accent capsule (AppKit counterpart of `PrimaryPillButtonStyle`).
@MainActor
private final class AccentPillButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false { didSet { updateFill() } }

    init(title: String, height: CGFloat, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = height / 2
        layer?.cornerCurve = .continuous
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        setAccessibilityLabel(title)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            widthAnchor.constraint(equalToConstant: ceil(attributedTitle.size().width) + DS.Space.m * 2),
        ])
        updateFill()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent) { isHovering = false }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateFill()
    }

    private func updateFill() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = DS.Palette.accent
            let fill = isHovering ? (accent.highlight(withLevel: 0.12) ?? accent) : accent
            layer?.backgroundColor = fill.cgColor
        }
    }
}
