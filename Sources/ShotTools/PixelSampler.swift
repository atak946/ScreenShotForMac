import CoreGraphics
import Foundation
import ShotCore

/// Integer pixel position inside a snapshot image (top-left origin).
struct PixelCoordinate: Equatable, Sendable {
    let x: Int
    let y: Int
}

/// A cropped part of the snapshot around a pixel, positioned inside a square grid.
struct PixelRegion {
    let image: CGImage
    /// Offset of the crop inside the requested grid, in pixels from the top-left.
    let offsetX: Int
    let offsetY: Int
    /// Grid width / height in pixels.
    let gridSize: Int
}

/// Maps global AppKit points onto snapshot pixels and reads sRGB colors.
struct PixelSampler {
    let image: CGImage
    /// Global AppKit rect (points, bottom-left origin) covered by `image`.
    let screenRect: CGRect

    init?(capture: CaptureResult) {
        guard capture.screenRect.width > 0, capture.screenRect.height > 0,
              capture.image.width > 0, capture.image.height > 0 else { return nil }
        image = capture.image
        screenRect = capture.screenRect
    }

    private var pixelsPerPointX: CGFloat { CGFloat(image.width) / screenRect.width }
    private var pixelsPerPointY: CGFloat { CGFloat(image.height) / screenRect.height }

    func pixel(at globalPoint: CGPoint) -> PixelCoordinate {
        let x = Int(((globalPoint.x - screenRect.minX) * pixelsPerPointX).rounded(.down))
        let y = Int(((screenRect.maxY - globalPoint.y) * pixelsPerPointY).rounded(.down))
        return clamped(x: x, y: y)
    }

    func clamped(x: Int, y: Int) -> PixelCoordinate {
        PixelCoordinate(x: min(max(x, 0), image.width - 1), y: min(max(y, 0), image.height - 1))
    }

    /// Global AppKit point at the center of the given pixel.
    func globalPoint(forPixelCenter pixel: PixelCoordinate) -> CGPoint {
        CGPoint(
            x: screenRect.minX + (CGFloat(pixel.x) + 0.5) / pixelsPerPointX,
            y: screenRect.maxY - (CGFloat(pixel.y) + 0.5) / pixelsPerPointY
        )
    }

    /// Reads the pixel converted to 8-bit sRGB.
    func color(at pixel: PixelCoordinate) -> PickedColor? {
        let rect = CGRect(x: pixel.x, y: pixel.y, width: 1, height: 1)
        guard let crop = image.cropping(to: rect),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var buffer = [UInt8](repeating: 0, count: 4)
        let didDraw = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard didDraw else { return nil }
        return Self.unpremultiplied(buffer)
    }

    /// Crops a (2 * radius + 1)-pixel square centered on `center`, clipped to the image bounds.
    func region(around center: PixelCoordinate, radius: Int) -> PixelRegion? {
        let size = radius * 2 + 1
        let requested = CGRect(x: center.x - radius, y: center.y - radius, width: size, height: size)
        let visible = requested.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !visible.isNull, !visible.isEmpty, let crop = image.cropping(to: visible) else { return nil }
        return PixelRegion(
            image: crop,
            offsetX: Int(visible.minX - requested.minX),
            offsetY: Int(visible.minY - requested.minY),
            gridSize: size
        )
    }

    private static func unpremultiplied(_ rgba: [UInt8]) -> PickedColor {
        let alpha = Double(rgba[3]) / 255
        guard alpha > 0 else { return PickedColor(red: 0, green: 0, blue: 0, alpha: 0) }
        let channel = { (value: UInt8) in min(Double(value) / 255 / alpha, 1) }
        return PickedColor(red: channel(rgba[0]), green: channel(rgba[1]), blue: channel(rgba[2]), alpha: alpha)
    }
}
