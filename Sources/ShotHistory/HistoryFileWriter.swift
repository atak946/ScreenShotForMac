import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers

public enum HistoryError: LocalizedError, Sendable {
    case directoryUnavailable(String)
    case encodingFailed(String)
    case outsideHistoryDirectory(String)

    public var errorDescription: String? {
        switch self {
        case let .directoryUnavailable(path): return String(localized: "History folder is not available: \(path)", bundle: .module)
        case let .encodingFailed(name): return String(localized: "Could not write history file \(name).", bundle: .module)
        case let .outsideHistoryDirectory(path): return String(
                localized: "Refusing to touch a file outside the history folder: \(path)",
                bundle: .module
            )
        }
    }
}

/// File-level helpers for the history store. All functions are nonisolated and
/// safe to call from background tasks.
enum HistoryFileWriter {
    static let thumbnailMaxPixels: CGFloat = 400
    private static let thumbnailQuality = 0.8
    private static let baseDPI: CGFloat = 72

    /// Writes a lossless PNG with DPI metadata (72 × scale) so Retina captures open at point size.
    static func writePNG(_ image: CGImage, scale: CGFloat, to url: URL) throws {
        let dpi = baseDPI * max(scale, 1)
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        try write(image, type: .png, properties: properties, to: url)
    }

    /// Writes a JPEG thumbnail (longest side ≤ 400 px) flattened onto white.
    static func writeThumbnail(of image: CGImage, to url: URL) throws {
        let thumbnail = downscaled(image, maxPixels: thumbnailMaxPixels) ?? image
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: thumbnailQuality]
        try write(thumbnail, type: .jpeg, properties: properties, to: url)
    }

    /// Builds the thumbnail of a recording (first video frame or first GIF frame).
    static func writeMediaThumbnail(source: URL, kind: HistoryItem.Kind, to url: URL) async throws {
        let frame: CGImage? = switch kind {
        case .gif, .image:
            firstFrame(ofImageAt: source)
        case .video:
            try await firstFrame(ofVideoAt: source)
        }
        guard let frame else { throw HistoryError.encodingFailed(url.lastPathComponent) }
        try writeThumbnail(of: frame, to: url)
    }

    static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    static func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }

    // MARK: - Private

    private static func write(_ image: CGImage, type: UTType, properties: [CFString: Any], to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw HistoryError.encodingFailed(url.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw HistoryError.encodingFailed(url.lastPathComponent)
        }
    }

    private static func downscaled(_ image: CGImage, maxPixels: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0 else { return nil }
        let factor = min(1, maxPixels / max(width, height))
        let size = CGSize(width: max(1, (width * factor).rounded()), height: max(1, (height * factor).rounded()))
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    private static func firstFrame(ofImageAt url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func firstFrame(ofVideoAt url: URL) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailMaxPixels, height: thumbnailMaxPixels)
        let (image, _) = try await generator.image(at: .zero)
        return image
    }
}
