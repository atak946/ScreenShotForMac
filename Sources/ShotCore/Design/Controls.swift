import AppKit
import SwiftUI

// MARK: - AppKit icon button

/// Borderless SF Symbol button with designed hover / pressed / selected states.
/// Accepts the first click (works inside non-activating panels).
@MainActor
public final class IconButton: NSButton {
    public var isSelectedState = false { didSet { updateAppearance() } }
    public var tint: NSColor? { didSet { updateAppearance() } }

    private var isHovering = false { didSet { updateAppearance() } }
    private var trackingArea: NSTrackingArea?
    private let side: CGFloat

    public init(
        symbol: String,
        tooltip: String,
        size: CGFloat = DS.Size.iconButton,
        pointSize: CGFloat = DS.Size.symbolPointSize,
        target: AnyObject?,
        action: Selector?
    ) {
        side = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.target = target
        self.action = action
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium))
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        isBordered = false
        imagePosition = .imageOnly
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = DS.Radius.control
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
        ])
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public var intrinsicContentSize: NSSize { NSSize(width: side, height: side) }
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public func setSymbol(_ symbol: String, tooltip: String) {
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(.init(pointSize: DS.Size.symbolPointSize, weight: .medium))
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override public func mouseEntered(with event: NSEvent) { isHovering = true }
    override public func mouseExited(with event: NSEvent) { isHovering = false }

    override public func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isSelectedState {
                layer?.backgroundColor = DS.Palette.accent.cgColor
                contentTintColor = .white
            } else {
                layer?.backgroundColor = isHovering ? NSColor.labelColor.withAlphaComponent(0.1).cgColor : nil
                contentTintColor = tint ?? .labelColor
            }
        }
    }
}

// MARK: - SwiftUI button styles

/// Square icon button for toolbars: hover fill, pressed scale, selected = accent fill.
public struct ToolButtonStyle: ButtonStyle {
    let isSelected: Bool
    let size: CGFloat

    public init(isSelected: Bool = false, size: CGFloat = DS.Size.iconButton) {
        self.isSelected = isSelected
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        ToolButtonBody(configuration: configuration, isSelected: isSelected, size: size)
    }
}

private struct ToolButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let size: CGFloat
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: DS.Size.symbolPointSize, weight: .medium))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor) }
        if configuration.isPressed { return AnyShapeStyle(Color.primary.opacity(0.16)) }
        return AnyShapeStyle(Color.primary.opacity(isHovering ? 0.08 : 0))
    }
}

/// Prominent capsule action (e.g. "Save", "Capture"): accent fill, white label.
public struct PrimaryPillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Space.m)
            .frame(height: DS.Size.iconButton)
            .background(Color.accentColor, in: Capsule())
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
    }
}

/// Thin vertical divider for toolbars.
public struct ToolbarDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 18)
            .padding(.horizontal, DS.Space.xs)
    }
}

/// Small rounded "key cap" for shortcut hints, e.g. ⌥⇧1.
public struct KeyCap: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.dsStroke))
    }
}
