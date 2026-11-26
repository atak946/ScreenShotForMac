import CoreGraphics
import Foundation

/// 8-bit RGBA pixel used by synthetic test images.
public struct TestPixel: Equatable, Sendable, CustomStringConvertible {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let red = TestPixel(255, 0, 0)
    public static let green = TestPixel(0, 255, 0)
    public static let blue = TestPixel(0, 0, 255)
    public static let white = TestPixel(255, 255, 255)
    public static let black = TestPixel(0, 0, 0)

    public var description: String {
        "(\(red), \(green), \(blue), \(alpha))"
    }

    /// Largest per-channel difference.
    public func distance(to other: TestPixel) -> Int {
        max(
            abs(Int(red) - Int(other.red)),
            abs(Int(green) - Int(other.green)),
            abs(Int(blue) - Int(other.blue)),
            abs(Int(alpha) - Int(other.alpha))
        )
    }
}

/// Builds and inspects synthetic CGImages (sRGB, RGBA8, top-left origin).
public enum TestImages {
    private static let bytesPerPixel = 4

    /// Image whose pixel at (x, y) (top-left origin) is `pixel(x, y)`.
    public static func make(width: Int, height: Int, pixel: (Int, Int) -> TestPixel) -> CGImage? {
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let value = pixel(x, y)
                let offset = y * bytesPerRow + x * bytesPerPixel
                bytes[offset] = value.red
                bytes[offset + 1] = value.green
                bytes[offset + 2] = value.blue
                bytes[offset + 3] = value.alpha
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * bytesPerPixel,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    public static func solid(width: Int, height: Int, color: TestPixel) -> CGImage? {
        make(width: width, height: height) { _, _ in color }
    }

    /// Decodes `image` into RGBA8 sRGB bytes, row 0 = top.
    public static func pixels(of image: CGImage) -> [TestPixel]? {
        let width = image.width
        let height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let didDraw = data.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }
        return stride(from: 0, to: data.count, by: bytesPerPixel).map { offset in
            TestPixel(data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
        }
    }

    /// Pixel at (x, y), top-left origin.
    public static func pixel(of image: CGImage, x: Int, y: Int) -> TestPixel? {
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
        return pixels(of: image)?[y * image.width + x]
    }
}
