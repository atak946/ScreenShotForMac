import CoreGraphics
import Foundation
import ShotCore

/// Integer pixel position inside a snapshot (top-left origin).
struct PixelPoint: Equatable, Sendable {
    let x: Int
    let y: Int
}

/// Inclusive pixel rectangle inside a snapshot (top-left origin).
struct PixelRect: Equatable, Sendable {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }

    func contains(_ point: PixelPoint) -> Bool {
        (minX...maxX).contains(point.x) && (minY...maxY).contains(point.y)
    }
}

/// 8-bit sRGB color of one pixel.
struct RGBColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    /// Largest per-channel difference (0...255).
    func distance(to other: RGBColor) -> Int {
        max(
            abs(Int(red) - Int(other.red)),
            abs(Int(green) - Int(other.green)),
            abs(Int(blue) - Int(other.blue))
        )
    }
}

/// Decoded RGBA8 copy of a snapshot, safe to share across concurrency domains.
struct PixelBuffer: Sendable {
    private static let bytesPerPixel = 4

    let width: Int
    let height: Int
    private let bytes: [UInt8]

    /// Renders the image into an sRGB RGBA8 buffer. Returns nil for empty images or context failures.
    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = width * Self.bytesPerPixel
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let didDraw = data.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }
        self.width = width
        self.height = height
        bytes = data
    }

    func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    func clamped(x: Int, y: Int) -> PixelPoint {
        PixelPoint(x: min(max(x, 0), width - 1), y: min(max(y, 0), height - 1))
    }

    /// Color at an in-bounds pixel; out-of-bounds coordinates are clamped.
    func color(x: Int, y: Int) -> RGBColor {
        let point = clamped(x: x, y: y)
        let offset = (point.y * width + point.x) * Self.bytesPerPixel
        return RGBColor(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
    }

    /// Decodes every snapshot concurrently off the main actor. Order matches `captures`.
    static func makeAll(from captures: [CaptureResult]) async -> [PixelBuffer?] {
        await withTaskGroup(of: (Int, PixelBuffer?).self) { group in
            for (index, capture) in captures.enumerated() {
                group.addTask { (index, PixelBuffer(image: capture.image)) }
            }
            var result = [PixelBuffer?](repeating: nil, count: captures.count)
            for await (index, buffer) in group {
                result[index] = buffer
            }
            return result
        }
    }
}
