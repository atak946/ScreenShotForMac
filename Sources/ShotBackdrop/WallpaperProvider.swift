import AppKit
import CoreImage
import ImageIO
import ShotCore

/// Loads the current desktop wallpaper (downsampled) and caches blurred variants.
@MainActor
public final class WallpaperProvider {
    private static let maxPixelSize = 1600
    /// Few radii are kept so preset thumbnails and the live preview don't evict each other.
    private static let maxCachedRadii = 4

    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var source: CGImage?
    private var didLoad = false
    private var cache: [Double: CGImage] = [:]

    public init() {}

    /// Blurred wallpaper for the given radius, or nil if no wallpaper is readable.
    public func blurred(radius: Double) -> CGImage? {
        if let cached = cache[radius] {
            return cached
        }
        guard let base = loadSource() else { return nil }
        let result = radius > 0 ? blur(base, radius: radius) ?? base : base
        if cache.count >= Self.maxCachedRadii { cache.removeAll() }
        cache[radius] = result
        return result
    }

    private func loadSource() -> CGImage? {
        if didLoad { return source }
        didLoad = true
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen, let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            Log.editor.info("No desktop wallpaper URL available")
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
        ]
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else {
            Log.editor.error("Could not read desktop wallpaper image")
            return nil
        }
        source = image
        return image
    }

    private func blur(_ image: CGImage, radius: Double) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }
}
