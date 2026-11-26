import AppKit
import ShotCore

/// Circular loupe with a zoomed pixel grid of the frozen snapshot around the cursor, a
/// crosshair on the center pixel and a glass pill with coordinates and hex color below.
/// Purely visual: it never receives mouse events.
@MainActor
final class MagnifierView: NSView {
    /// Number of sampled pixels per side (odd so there is a center pixel).
    static let gridSize = 15
    /// On-screen size of one sampled pixel in points (~8x zoom).
    static let cellSize: CGFloat = 8
    static let loupeSide = CGFloat(gridSize) * cellSize
    private static let pillGap: CGFloat = DS.Space.s
    private static let pillHeight: CGFloat = 22
    private static let width: CGFloat = 176
    static let totalSize = CGSize(width: width, height: loupeSide + pillGap + pillHeight)

    private var image: CGImage?
    private var pixel: (x: Int, y: Int) = (0, 0)
    private let pill = OverlayPill()

    private var loupeRect: CGRect {
        CGRect(x: (Self.width - Self.loupeSide) / 2, y: 0, width: Self.loupeSide, height: Self.loupeSide)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        addSubview(pill)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Updates the sampled pixel. `pixel` is in image coordinates (top-left origin).
    func update(image: CGImage, pixel: (x: Int, y: Int), pointLabel: String) {
        self.image = image
        self.pixel = pixel
        let hex = PixelColor.hex(in: image, x: pixel.x, y: pixel.y)
        let text = [pointLabel, hex].compactMap(\.self).joined(separator: "   ")
        let center = CGPoint(x: Self.width / 2, y: Self.loupeSide + Self.pillGap + Self.pillHeight / 2)
        pill.show(text, centeredAt: center)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let loupe = loupeRect
        let clip = CGPath(ellipseIn: loupe, transform: nil)

        context.saveGState()
        context.addPath(clip)
        context.clip()
        context.setFillColor(NSColor.black.cgColor)
        context.fill(loupe)
        context.translateBy(x: loupe.minX, y: loupe.minY)
        drawPixels(in: context)
        drawGrid(in: context)
        drawCrosshair(in: context)
        context.restoreGState()

        drawRing(clip, in: context)
    }

    private func drawRing(_ clip: CGPath, in context: CGContext) {
        context.addPath(clip)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(2)
        context.strokePath()
        context.addPath(clip)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }

    private func drawPixels(in context: CGContext) {
        guard let image else { return }
        let half = Self.gridSize / 2
        let wanted = CGRect(x: pixel.x - half, y: pixel.y - half, width: Self.gridSize, height: Self.gridSize)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let available = wanted.intersection(bounds)
        guard !available.isNull, let piece = image.cropping(to: available) else { return }

        let destination = CGRect(
            x: (available.minX - wanted.minX) * Self.cellSize,
            y: (available.minY - wanted.minY) * Self.cellSize,
            width: available.width * Self.cellSize,
            height: available.height * Self.cellSize
        )
        context.saveGState()
        context.interpolationQuality = .none
        // The view is flipped; flip locally so the CGImage draws upright.
        context.translateBy(x: 0, y: destination.maxY + destination.minY)
        context.scaleBy(x: 1, y: -1)
        context.draw(piece, in: destination)
        context.restoreGState()
    }

    private func drawGrid(in context: CGContext) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(0.5)
        for index in 1..<Self.gridSize {
            let offset = CGFloat(index) * Self.cellSize
            context.move(to: CGPoint(x: offset, y: 0))
            context.addLine(to: CGPoint(x: offset, y: Self.loupeSide))
            context.move(to: CGPoint(x: 0, y: offset))
            context.addLine(to: CGPoint(x: Self.loupeSide, y: offset))
        }
        context.strokePath()
    }

    /// Tinted row / column through the center pixel plus a high-contrast outline on it.
    private func drawCrosshair(in context: CGContext) {
        let origin = CGFloat(Self.gridSize / 2) * Self.cellSize
        context.setFillColor(DS.Palette.accent.withAlphaComponent(0.22).cgColor)
        context.fill(CGRect(x: origin, y: 0, width: Self.cellSize, height: origin))
        context.fill(CGRect(x: origin, y: origin + Self.cellSize, width: Self.cellSize, height: origin))
        context.fill(CGRect(x: 0, y: origin, width: origin, height: Self.cellSize))
        context.fill(CGRect(x: origin + Self.cellSize, y: origin, width: origin, height: Self.cellSize))

        let cell = CGRect(x: origin, y: origin, width: Self.cellSize, height: Self.cellSize).insetBy(dx: -0.5, dy: -0.5)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(2.5)
        context.stroke(cell)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        context.stroke(cell)
    }
}

/// Reads one pixel of a CGImage as an sRGB hex string.
enum PixelColor {
    static func hex(in image: CGImage, x: Int, y: Int) -> String? {
        guard x >= 0, y >= 0, x < image.width, y < image.height,
              let piece = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(piece, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
}
