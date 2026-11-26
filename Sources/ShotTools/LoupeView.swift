import AppKit
import ShotCore

/// What the loupe shows for the current cursor position.
struct LoupeContent {
    let region: PixelRegion?
    let color: PickedColor
    let label: String
}

/// Circular, nearest-neighbor magnified pixel grid with a glass pill (swatch + value) below.
/// Matches the capture magnifier.
@MainActor
final class LoupeView: NSView {
    static let gridPixels = 15
    static let zoom: CGFloat = 12
    static let gridSide = CGFloat(gridPixels) * zoom
    private static let labelHeight: CGFloat = 26
    private static let spacing: CGFloat = DS.Space.s
    private static let swatchSide: CGFloat = 12
    private static let labelPadding: CGFloat = DS.Space.s + DS.Space.xxs
    private static let swatchGap: CGFloat = DS.Space.s - DS.Space.xxs
    private static var font: NSFont { DS.Font.numeric }

    private var content: LoupeContent?
    private let labelSurface = GlassSurfaceView(cornerRadius: labelHeight / 2, forceDark: true)
    private let swatch = NSView()
    private let valueLabel = NSTextField(labelWithString: "")

    /// Distance from the view's bottom edge to the center of the pixel grid.
    static let gridCenterOffsetY = labelHeight + spacing + gridSide / 2

    static func size(for label: String) -> CGSize {
        CGSize(width: max(gridSide, labelWidth(for: label)), height: gridSide + spacing + labelHeight)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        configureLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(_ content: LoupeContent) {
        self.content = content
        let color = content.color
        swatch.layer?.backgroundColor = NSColor(
            srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha
        ).cgColor
        valueLabel.stringValue = content.label
        layoutLabel()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let content, let context = NSGraphicsContext.current?.cgContext else { return }
        let gridRect = CGRect(
            x: (bounds.width - Self.gridSide) / 2, y: Self.labelHeight + Self.spacing,
            width: Self.gridSide, height: Self.gridSide
        )
        drawGrid(content.region, in: gridRect, context: context)
    }

    // MARK: Label pill

    private static func labelWidth(for text: String) -> CGFloat {
        let textWidth = NSAttributedString(string: text, attributes: [.font: font]).size().width
        return (labelPadding * 2 + swatchSide + swatchGap + textWidth).rounded(.up)
    }

    private func configureLabel() {
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = Self.swatchSide / 2
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        valueLabel.font = Self.font
        valueLabel.textColor = .white
        labelSurface.contentView.addSubview(swatch)
        labelSurface.contentView.addSubview(valueLabel)
        addSubview(labelSurface)
    }

    private func layoutLabel() {
        let width = Self.labelWidth(for: valueLabel.stringValue)
        labelSurface.frame = CGRect(x: ((bounds.width - width) / 2).rounded(), y: 0, width: width, height: Self.labelHeight)
        swatch.frame = CGRect(
            x: Self.labelPadding, y: (Self.labelHeight - Self.swatchSide) / 2,
            width: Self.swatchSide, height: Self.swatchSide
        )
        let textHeight = valueLabel.intrinsicContentSize.height
        valueLabel.frame = CGRect(
            x: swatch.frame.maxX + Self.swatchGap,
            y: ((Self.labelHeight - textHeight) / 2).rounded(),
            width: width - swatch.frame.maxX - Self.swatchGap - Self.labelPadding + 2,
            height: textHeight
        )
    }

    // MARK: Grid

    private func drawGrid(_ region: PixelRegion?, in rect: CGRect, context: CGContext) {
        let outline = NSBezierPath(ovalIn: rect)
        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        NSColor.black.setFill()
        rect.fill()
        if let region {
            context.interpolationQuality = .none
            let zoom = Self.zoom
            let imageRect = CGRect(
                x: rect.minX + CGFloat(region.offsetX) * zoom,
                y: rect.maxY - CGFloat(region.offsetY + region.image.height) * zoom,
                width: CGFloat(region.image.width) * zoom,
                height: CGFloat(region.image.height) * zoom
            )
            context.draw(region.image, in: imageRect)
        }
        drawGridLines(in: rect)
        drawCrosshair(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        drawRing(outline)
    }

    private func drawRing(_ outline: NSBezierPath) {
        NSColor.black.withAlphaComponent(0.35).setStroke()
        outline.lineWidth = 2
        outline.stroke()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }

    private func drawGridLines(in rect: CGRect) {
        let path = NSBezierPath()
        for index in 1..<Self.gridPixels {
            let offset = CGFloat(index) * Self.zoom
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.line(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + offset))
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY + offset))
        }
        path.lineWidth = 0.5
        NSColor.white.withAlphaComponent(0.1).setStroke()
        path.stroke()
    }

    /// Tinted row / column through the center pixel plus a high-contrast outline on it.
    private func drawCrosshair(in rect: CGRect) {
        let half = CGFloat(Self.gridPixels / 2) * Self.zoom
        let cell = CGRect(x: rect.minX + half, y: rect.minY + half, width: Self.zoom, height: Self.zoom)
        DS.Palette.accent.withAlphaComponent(0.22).setFill()
        CGRect(x: cell.minX, y: rect.minY, width: Self.zoom, height: half).fill(using: .sourceOver)
        CGRect(x: cell.minX, y: cell.maxY, width: Self.zoom, height: half).fill(using: .sourceOver)
        CGRect(x: rect.minX, y: cell.minY, width: half, height: Self.zoom).fill(using: .sourceOver)
        CGRect(x: cell.maxX, y: cell.minY, width: half, height: Self.zoom).fill(using: .sourceOver)

        let outer = NSBezierPath(rect: cell.insetBy(dx: -1, dy: -1))
        outer.lineWidth = 2
        NSColor.black.setStroke()
        outer.stroke()
        let inner = NSBezierPath(rect: cell)
        inner.lineWidth = 1.5
        NSColor.white.setStroke()
        inner.stroke()
    }
}
