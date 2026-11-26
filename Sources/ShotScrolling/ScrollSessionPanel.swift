import AppKit
import ShotCore

/// Actions the user can trigger from the session panel.
@MainActor
struct ScrollPanelActions {
    let toggleAutoScroll: @MainActor () -> Void
    let done: @MainActor () -> Void
    let cancel: @MainActor () -> Void
}

/// Non-activating glass card: status title, size, live height preview, auto-scroll and
/// cancel icon buttons and the accent Done pill. Visually matches the recording controls.
@MainActor
final class ScrollSessionPanel: NSPanel {
    private static let size = CGSize(width: 320, height: 104)
    private static let gap: CGFloat = DS.Space.m
    private static let pillHeight: CGFloat = 28
    private static let accessibilityHint =
        String(
            localized: "Auto-scroll needs Accessibility permission. Enable it in System Settings > Privacy & Security > Accessibility.",
            bundle: .module
        )

    private let statusLabel = NSTextField(labelWithString: String(localized: "Scroll now…", bundle: .module))
    private let sizeLabel = NSTextField(labelWithString: "")
    private let preview = StitchHeightPreview(frame: CGRect(x: 0, y: 0, width: 28, height: 72))
    private let autoButton: IconButton
    private let cancelButton: IconButton
    private let doneButton: AccentPillButton
    private let actions: ScrollPanelActions

    init(area: CGRect, screen: NSScreen, actions: ScrollPanelActions, canAutoScroll: Bool) {
        self.actions = actions
        autoButton = IconButton(
            symbol: "arrow.down.circle",
            tooltip: String(localized: "Auto-scroll", bundle: .module),
            target: nil,
            action: nil
        )
        cancelButton = IconButton(symbol: "xmark", tooltip: String(localized: "Cancel", bundle: .module), target: nil, action: nil)
        doneButton = AccentPillButton(title: String(localized: "Done", bundle: .module), height: Self.pillHeight)
        let frame = Self.placement(for: area, in: screen.visibleFrame)
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        configureWindow()
        contentView = makeContent(canAutoScroll: canAutoScroll)
    }

    override var canBecomeKey: Bool { true }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func setAutoScrolling(_ isOn: Bool) {
        autoButton.isSelectedState = isOn
        autoButton.setSymbol(
            isOn ? "stop.circle" : "arrow.down.circle",
            tooltip: isOn ? String(localized: "Stop Auto-scroll", bundle: .module) : String(localized: "Auto-scroll", bundle: .module)
        )
    }

    func updateSize(pixelWidth: Int, pixelHeight: Int, frameHeight: Int) {
        sizeLabel.stringValue = pixelHeight > 0 ? "\(pixelWidth) × \(pixelHeight) px" : ""
        preview.update(totalHeight: pixelHeight, frameHeight: frameHeight)
    }

    // MARK: - Setup

    private func configureWindow() {
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    private func makeContent(canAutoScroll: Bool) -> NSView {
        let surface = GlassSurfaceView(cornerRadius: DS.Radius.panel)
        surface.frame = CGRect(origin: .zero, size: Self.size)
        configureControls(canAutoScroll: canAutoScroll)

        let buttons = NSStackView(views: [autoButton, cancelButton, NSView(), doneButton])
        buttons.orientation = .horizontal
        buttons.spacing = DS.Space.xs
        let texts = NSStackView(views: [statusLabel, sizeLabel])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = DS.Space.xxs
        let column = NSStackView(views: [texts, buttons])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = DS.Space.s
        let root = NSStackView(views: [preview, column])
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = DS.Space.m
        root.edgeInsets = NSEdgeInsets(top: DS.Space.m, left: DS.Space.m + DS.Space.xxs, bottom: DS.Space.m, right: DS.Space.m)
        root.frame = surface.contentView.bounds
        root.autoresizingMask = [.width, .height]
        surface.contentView.addSubview(root)
        NSLayoutConstraint.activate([
            preview.widthAnchor.constraint(equalToConstant: 28),
            preview.heightAnchor.constraint(equalToConstant: 72),
            buttons.widthAnchor.constraint(equalTo: column.widthAnchor),
        ])
        return surface
    }

    private func configureControls(canAutoScroll: Bool) {
        statusLabel.font = DS.Font.hudTitle
        statusLabel.lineBreakMode = .byTruncatingTail
        sizeLabel.font = DS.Font.numeric
        sizeLabel.textColor = .secondaryLabelColor
        for button in [autoButton, cancelButton, doneButton] as [NSButton] {
            button.target = self
        }
        autoButton.action = #selector(autoTapped)
        doneButton.action = #selector(doneTapped)
        cancelButton.action = #selector(cancelTapped)
        doneButton.keyEquivalent = "\r"
        autoButton.isEnabled = canAutoScroll
        autoButton.alphaValue = canAutoScroll ? 1 : 0.4
        autoButton.toolTip = canAutoScroll ? String(localized: "Scroll the area automatically", bundle: .module) : Self.accessibilityHint
    }

    @objc
    private func autoTapped() { actions.toggleAutoScroll() }
    @objc
    private func doneTapped() { actions.done() }
    @objc
    private func cancelTapped() { actions.cancel() }

    /// Right of the area, else left, else inside the area's bottom-right corner; clamped to the screen.
    private static func placement(for area: CGRect, in visible: CGRect) -> CGRect {
        var origin = CGPoint(x: area.maxX + gap, y: area.maxY - size.height)
        if origin.x + size.width > visible.maxX {
            origin.x = area.minX - gap - size.width
        }
        if origin.x < visible.minX {
            origin = CGPoint(x: area.maxX - size.width - gap, y: area.minY + gap)
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }
}

/// Prominent accent capsule (AppKit counterpart of `PrimaryPillButtonStyle`). Accepts first mouse.
@MainActor
final class AccentPillButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false { didSet { updateFill() } }

    init(title: String, height: CGFloat) {
        super.init(frame: .zero)
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
            widthAnchor.constraint(equalToConstant: ceil(attributedTitle.size().width) + DS.Space.l * 2),
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

/// Mini preview: a page outline with the viewport drawn proportionally to the stitched height.
@MainActor
final class StitchHeightPreview: NSView {
    private var totalHeight = 0
    private var frameHeight = 0

    override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 72) }

    func update(totalHeight: Int, frameHeight: Int) {
        self.totalHeight = totalHeight
        self.frameHeight = frameHeight
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let page = bounds.insetBy(dx: 1, dy: 1)
        let outline = NSBezierPath(roundedRect: page, xRadius: 3, yRadius: 3)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        outline.fill()
        NSColor.labelColor.withAlphaComponent(0.4).setStroke()
        outline.stroke()
        guard totalHeight > 0, frameHeight > 0 else { return }
        let ratio = min(1, CGFloat(frameHeight) / CGFloat(totalHeight))
        let viewport = CGRect(x: page.minX + 2, y: page.minY + 2, width: page.width - 4, height: max(3, (page.height - 4) * ratio))
        DS.Palette.accent.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: viewport, xRadius: 2, yRadius: 2).fill()
    }
}
