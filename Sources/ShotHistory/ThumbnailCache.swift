import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ShotCore

/// In-memory NSImage cache for history thumbnails. Files are decoded off the main thread.
/// Misses (e.g. thumbnail not written yet) are not cached, so a later load retries.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 500
        return cache
    }()

    func cachedImage(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = cachedImage(for: url) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) { DecodedImage.load(url) }.value
        guard let decoded else { return nil }
        let image = NSImage(cgImage: decoded.cgImage, size: .zero)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Synchronous load for menus (thumbnails are small JPEGs).
    func imageSync(for url: URL) -> NSImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let decoded = DecodedImage.load(url) else { return nil }
        let image = NSImage(cgImage: decoded.cgImage, size: .zero)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    func evict(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

/// Sendable box so a decoded CGImage can cross from the background task.
private struct DecodedImage: @unchecked Sendable {
    let cgImage: CGImage

    static func load(_ url: URL) -> DecodedImage? {
        HistoryFileWriter.loadImage(at: url).map(DecodedImage.init)
    }
}
