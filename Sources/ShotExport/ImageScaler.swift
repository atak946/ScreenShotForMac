import CoreGraphics
import Foundation

/// Resizes CGImages. Pure helpers, safe from any actor.
enum ImageScaler {
    /// Returns the image and its effective scale after applying the downscale preference.
    static func prepare(_ image: CGImage, scale: CGFloat, downscale: Bool) -> (image: CGImage, scale: CGFloat) {
        let safeScale = scale > 0 ? scale : 1
        guard downscale, safeScale > 1 else { return (image, safeScale) }
        let width = max(1, Int((CGFloat(image.width) / safeScale).rounded()))
        let height = max(1, Int((CGFloat(image.height) / safeScale).rounded()))
        guard let scaled = resize(image, width: width, height: height) else {
            return (image, safeScale)
        }
        return (scaled, 1)
    }

    /// High quality resize into a new bitmap with the same color space.
    static func resize(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace.model == .rgb ? colorSpace : CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Aspect-fit size for a thumbnail of the given width.
    static func fitting(_ size: CGSize, width: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: width, height: width * 0.6) }
        let ratio = size.height / size.width
        let height = min(maxHeight, width * ratio)
        let finalWidth = height < width * ratio ? height / ratio : width
        return CGSize(width: finalWidth.rounded(), height: height.rounded())
    }
}
