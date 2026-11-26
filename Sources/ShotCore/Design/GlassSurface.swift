import AppKit
import SwiftUI

/// AppKit floating surface: Liquid Glass on macOS 26+, HUD vibrancy before that.
/// Put content into `contentView`. Draws a hairline border and clips to `cornerRadius`.
@MainActor
public final class GlassSurfaceView: NSView {
    public let contentView = NSView()
    public var cornerRadius: CGFloat {
        didSet { applyCornerRadius() }
    }

    private var backgroundView: NSView?
    private let strokeLayer = CAShapeLayer()

    public init(cornerRadius: CGFloat = DS.Radius.panel, forceDark: Bool = false) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        if forceDark { appearance = NSAppearance(named: .darkAqua) }
        installBackground()
        installContent()
        installStroke()
        applyCornerRadius()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func layout() {
        super.layout()
        strokeLayer.frame = bounds
        strokeLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: DS.Size.hairline / 2, dy: DS.Size.hairline / 2),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }

    override public func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            strokeLayer.strokeColor = DS.Palette.surfaceStroke.cgColor
        }
    }

    private func installBackground() {
        let background: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            background = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            background = effect
        }
        pin(background)
        backgroundView = background
    }

    private func installContent() {
        pin(contentView)
    }

    private func installStroke() {
        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = DS.Size.hairline
        strokeLayer.strokeColor = DS.Palette.surfaceStroke.cgColor
        layer?.addSublayer(strokeLayer)
    }

    private func applyCornerRadius() {
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        if #available(macOS 26.0, *), let glass = backgroundView as? NSGlassEffectView {
            glass.cornerRadius = cornerRadius
        } else {
            backgroundView?.wantsLayer = true
            backgroundView?.layer?.cornerRadius = cornerRadius
            backgroundView?.layer?.cornerCurve = .continuous
        }
        needsLayout = true
    }

    private func pin(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

// MARK: - SwiftUI

extension View {
    /// SwiftUI counterpart of `GlassSurfaceView`.
    @ViewBuilder
    public func glassSurface(cornerRadius: CGFloat = DS.Radius.panel) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.dsStroke, lineWidth: DS.Size.hairline)
                )
        }
    }
}

// MARK: - Floating panel factory

public enum FloatingPanel {
    /// Borderless, non-activating, transparent panel that hosts a `GlassSurfaceView`
    /// (or any view). Use for HUDs, toolbars and controls that must not steal focus.
    @MainActor
    public static func make(size: CGSize, level: NSWindow.Level = .floating) -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = level
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}
