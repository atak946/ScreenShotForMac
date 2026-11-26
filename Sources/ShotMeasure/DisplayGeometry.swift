import CoreGraphics
import Foundation

/// Converts between global AppKit points, window-local points and snapshot pixels for one display.
struct DisplayGeometry: Sendable {
    /// Global AppKit rect (points, bottom-left origin) covered by the snapshot.
    let screenRect: CGRect
    let pixelWidth: Int
    let pixelHeight: Int

    init?(screenRect: CGRect, pixelWidth: Int, pixelHeight: Int) {
        guard screenRect.width > 0, screenRect.height > 0, pixelWidth > 0, pixelHeight > 0 else { return nil }
        self.screenRect = screenRect
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    var scaleX: CGFloat { CGFloat(pixelWidth) / screenRect.width }
    var scaleY: CGFloat { CGFloat(pixelHeight) / screenRect.height }

    func contains(global point: CGPoint) -> Bool { screenRect.contains(point) }

    func pixel(atGlobal point: CGPoint) -> PixelPoint {
        let x = Int(((point.x - screenRect.minX) * scaleX).rounded(.down))
        let y = Int(((screenRect.maxY - point.y) * scaleY).rounded(.down))
        return clamped(x: x, y: y)
    }

    func clamped(x: Int, y: Int) -> PixelPoint {
        PixelPoint(x: min(max(x, 0), pixelWidth - 1), y: min(max(y, 0), pixelHeight - 1))
    }

    /// Pixel rect spanned by a drag between two global points (clamped to this display).
    func pixelRect(fromGlobal start: CGPoint, to end: CGPoint) -> PixelRect {
        let edgeX = { (value: CGFloat) in Int(((value - screenRect.minX) * scaleX).rounded()) }
        let edgeY = { (value: CGFloat) in Int(((screenRect.maxY - value) * scaleY).rounded()) }
        let x0 = min(max(edgeX(min(start.x, end.x)), 0), pixelWidth - 1)
        let x1 = min(max(edgeX(max(start.x, end.x)) - 1, x0), pixelWidth - 1)
        let y0 = min(max(edgeY(max(start.y, end.y)), 0), pixelHeight - 1)
        let y1 = min(max(edgeY(min(start.y, end.y)) - 1, y0), pixelHeight - 1)
        return PixelRect(minX: x0, minY: y0, maxX: x1, maxY: y1)
    }

    func globalPoint(forPixelCenter pixel: PixelPoint) -> CGPoint {
        let local = localPoint(forPixelCenter: pixel)
        return CGPoint(x: screenRect.minX + local.x, y: screenRect.minY + local.y)
    }

    // MARK: Window-local points (bottom-left origin)

    func localX(pixelEdge x: Int) -> CGFloat { CGFloat(x) / scaleX }

    func localY(pixelEdge y: Int) -> CGFloat { screenRect.height - CGFloat(y) / scaleY }

    func localPoint(forPixelCenter pixel: PixelPoint) -> CGPoint {
        CGPoint(
            x: (CGFloat(pixel.x) + 0.5) / scaleX,
            y: screenRect.height - (CGFloat(pixel.y) + 0.5) / scaleY
        )
    }

    func localRect(for rect: PixelRect) -> CGRect {
        CGRect(
            x: localX(pixelEdge: rect.minX),
            y: localY(pixelEdge: rect.maxY + 1),
            width: CGFloat(rect.width) / scaleX,
            height: CGFloat(rect.height) / scaleY
        )
    }
}
