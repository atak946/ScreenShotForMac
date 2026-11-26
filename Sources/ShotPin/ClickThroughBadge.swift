import AppKit
import ShotCore

/// Glass pill shown while any pin ignores mouse events; clicking it restores interaction.
@MainActor
final class ClickThroughBadge: NSPanel {
    private static let height: CGFloat = 30
    private static let margin: CGFloat = DS.Space.m
    private static let horizontalPadding: CGFloat = DS.Space.m

    private let surface = GlassSurfaceView(cornerRadius: height / 2)
    private let button = FirstMouseButton()
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: Self.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        configureButton()
        contentView = surface
    }

    func update(count: Int) {
        let title = count == 1
            ? String(localized: "Click-through: 1 pin · Disable", bundle: .module)
            : String(localized: "Click-through: \(count) pins · Disable", bundle: .module)
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: DS.Font.label,
            .foregroundColor: NSColor.labelColor,
        ])
        button.setAccessibilityLabel(title)
        resizeToFit()
        orderFrontRegardless()
    }

    private func configureButton() {
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.contentTintColor = DS.Palette.warning
        button.target = self
        button.action = #selector(clicked)
        button.toolTip = String(localized: "Restore mouse interaction for all pins", bundle: .module)
        button.autoresizingMask = [.width, .height]
        surface.contentView.addSubview(button)
    }

    private func resizeToFit() {
        let width = ceil(button.intrinsicContentSize.width + Self.horizontalPadding * 2)
        let size = CGSize(width: width, height: Self.height)
        button.frame = CGRect(origin: .zero, size: size)
        guard let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            setContentSize(size)
            return
        }
        let origin = CGPoint(x: visible.maxX - size.width - Self.margin, y: visible.maxY - size.height - Self.margin)
        setFrame(CGRect(origin: origin, size: size), display: true)
    }

    @objc
    private func clicked() {
        onClick()
    }
}
