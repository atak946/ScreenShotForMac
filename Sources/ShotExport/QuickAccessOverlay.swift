import AppKit
import ShotCore

/// Actions a Quick Access thumbnail can trigger. Raw values double as button tags.
enum QuickAccessAction: Int, Sendable {
    case edit
    case copy
    case save
    case pin
    case close
    case upload
}

/// Hover overlay: dimmed scrim, Copy / Save glass pills in the center, a small close chip
/// top-left and Edit / Pin / Upload chips top-right. Every control accepts the first click.
@MainActor
final class QuickAccessOverlay: NSView {
    private static let pillWidth: CGFloat = 92
    private static let pillHeight: CGFloat = 28
    private static let chipSize: CGFloat = 24
    private static let chipSymbolSize: CGFloat = 11
    private static let edgeInset: CGFloat = DS.Space.s
    private static let scrimAlpha: CGFloat = 0.32

    var onAction: ((QuickAccessAction) -> Void)?

    init(showsPin: Bool, showsUpload: Bool = false) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(Self.scrimAlpha).cgColor
        build(showsPin: showsPin, showsUpload: showsUpload)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func build(showsPin: Bool, showsUpload: Bool) {
        let pills = NSStackView(views: [
            pill(String(localized: "Copy", bundle: .module), action: .copy),
            pill(String(localized: "Save", bundle: .module), action: .save),
        ])
        pills.orientation = .vertical
        pills.spacing = DS.Space.s
        pills.translatesAutoresizingMaskIntoConstraints = false

        let close = chip(symbol: "xmark", label: String(localized: "Close", bundle: .module), action: .close)
        var trailingChips = [chip(symbol: "pencil", label: String(localized: "Edit", bundle: .module), action: .edit)]
        if showsPin {
            trailingChips.append(chip(symbol: "pin", label: String(localized: "Pin", bundle: .module), action: .pin))
        }
        if showsUpload {
            trailingChips.append(chip(
                symbol: "icloud.and.arrow.up", label: String(localized: "Upload", bundle: .module), action: .upload
            ))
        }
        let trailing = NSStackView(views: trailingChips)
        trailing.spacing = DS.Space.xs
        trailing.translatesAutoresizingMaskIntoConstraints = false

        [pills, close, trailing].forEach(addSubview)
        NSLayoutConstraint.activate([
            pills.centerXAnchor.constraint(equalTo: centerXAnchor),
            pills.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.topAnchor.constraint(equalTo: topAnchor, constant: Self.edgeInset),
            close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.edgeInset),
            trailing.topAnchor.constraint(equalTo: topAnchor, constant: Self.edgeInset),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.edgeInset),
        ])
    }

    /// Text action on a dark glass capsule.
    private func pill(_ title: String, action: QuickAccessAction) -> NSView {
        let button = QuickAccessPillButton(title: title, target: self, action: #selector(tapped(_:)))
        button.tag = action.rawValue
        return wrapInGlass(button, size: CGSize(width: Self.pillWidth, height: Self.pillHeight))
    }

    /// Small circular icon action on dark glass.
    private func chip(symbol: String, label: String, action: QuickAccessAction) -> NSView {
        let button = IconButton(
            symbol: symbol,
            tooltip: label,
            size: Self.chipSize,
            pointSize: Self.chipSymbolSize,
            target: self,
            action: #selector(tapped(_:))
        )
        button.tag = action.rawValue
        button.layer?.cornerRadius = Self.chipSize / 2
        return wrapInGlass(button, size: CGSize(width: Self.chipSize, height: Self.chipSize))
    }

    private func wrapInGlass(_ control: NSView, size: CGSize) -> NSView {
        let surface = GlassSurfaceView(cornerRadius: size.height / 2, forceDark: true)
        surface.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        surface.contentView.addSubview(control)
        NSLayoutConstraint.activate([
            surface.widthAnchor.constraint(equalToConstant: size.width),
            surface.heightAnchor.constraint(equalToConstant: size.height),
            control.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            control.topAnchor.constraint(equalTo: surface.contentView.topAnchor),
            control.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor),
        ])
        return surface
    }

    @objc
    private func tapped(_ sender: NSButton) {
        guard let action = QuickAccessAction(rawValue: sender.tag) else { return }
        onAction?(action)
    }
}

/// Borderless text button with a hover highlight; fills its glass capsule.
@MainActor
private final class QuickAccessPillButton: NSButton {
    private var trackingArea: NSTrackingArea?

    init(title: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        setAccessibilityLabel(title)
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

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
}
