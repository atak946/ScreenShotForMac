import CoreGraphics
import ShotCore

/// Finds the dominant color along the border of an image region (used by the smart eraser).
enum ImageSampler {
    private static let maxSampleSide = 256
    private static let borderThickness = 2

    /// `pixelRect` uses the image's top-left pixel coordinates.
    static func dominantBorderColor(in image: CGImage, pixelRect: CGRect) -> AnnotationColor? {
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let region = pixelRect.integral.intersection(imageRect)
        guard !region.isNull, region.width >= 1, region.height >= 1,
              let cropped = image.cropping(to: region)
        else { return nil }
        let scale = min(1, CGFloat(maxSampleSide) / max(region.width, region.height))
        let width = max(Int(region.width * scale), 1)
        let height = max(Int(region.height * scale), 1)
        guard let pixels = rgbaPixels(of: cropped, width: width, height: height) else { return nil }
        return dominantColor(pixels: pixels, width: width, height: height)
    }

    private static func rgbaPixels(of image: CGImage, width: Int, height: Int) -> [UInt8]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let success = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        if !success { Log.editor.error("Color sampling failed: could not create bitmap context") }
        return success ? buffer : nil
    }

    private struct Bucket {
        var count = 0
        var red = 0
        var green = 0
        var blue = 0
    }

    private static func dominantColor(pixels: [UInt8], width: Int, height: Int) -> AnnotationColor? {
        var buckets: [Int: Bucket] = [:]
        let thickness = min(borderThickness, max(min(width, height) / 2, 1))
        for y in 0..<height {
            let isBorderRow = y < thickness || y >= height - thickness
            for x in 0..<width where isBorderRow || x < thickness || x >= width - thickness {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
                let key = (red >> 4) << 8 | (green >> 4) << 4 | (blue >> 4)
                var bucket = buckets[key] ?? Bucket()
                bucket.count += 1
                bucket.red += red
                bucket.green += green
                bucket.blue += blue
                buckets[key] = bucket
            }
        }
        // Every stored bucket has count >= 1 (incremented before insertion), so the divisor is never zero.
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let divisor = CGFloat(best.count) * 255
        return AnnotationColor(red: CGFloat(best.red) / divisor, green: CGFloat(best.green) / divisor, blue: CGFloat(best.blue) / divisor)
    }
}
