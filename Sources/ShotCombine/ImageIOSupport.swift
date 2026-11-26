import CoreGraphics
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers

/// Sendable box so a `CGImage` can cross into and out of background tasks.
struct ImageBox: @unchecked Sendable {
    let image: CGImage
}

enum ImageLoading {
    private static let baseDPI: CGFloat = 72

    /// Decodes the first frame of an image file; scale derives from its DPI (144 dpi = 2x).
    static func load(url: URL) -> CombineImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return decode(source)
    }

    static func load(data: Data) -> CombineImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return decode(source)
    }

    private static func decode(_ source: CGImageSource) -> CombineImage? {
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpi = (properties?[kCGImagePropertyDPIWidth] as? NSNumber).map { CGFloat($0.doubleValue) } ?? baseDPI
        let scale = max(1, (dpi / baseDPI).rounded())
        return CombineImage(image: image, scale: scale)
    }

    /// Uniformly downscaled copy whose longest side is at most `maxPixels`. Keeps point size.
    static func downscaled(_ source: CombineImage, maxPixels: CGFloat) -> CombineImage {
        let image = source.image
        let longest = CGFloat(max(image.width, image.height))
        let factor = min(1, maxPixels / max(longest, 1))
        guard factor < 1 else { return source }
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return source }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return source }
        return CombineImage(image: scaled, scale: source.scale * CGFloat(width) / CGFloat(image.width))
    }
}

enum PNGWriter {
    enum WriteError: Error {
        case destinationUnavailable(URL)
        case finalizeFailed(URL)
    }

    /// Writes `image` as PNG with DPI metadata matching `scale`.
    static func write(_ image: CGImage, scale: CGFloat, to url: URL) throws(WriteError) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw .destinationUnavailable(url)
        }
        let dpi = 72 * max(scale, 1)
        let properties: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .finalizeFailed(url) }
    }

    /// Writes all slices into `folder` as "<base> 01.png", "<base> 02.png", … without overwriting.
    /// Returns the number of files written.
    static func writeSlices(_ slices: [ImageBox], scale: CGFloat, folder: URL, baseName: String) -> Int {
        var written = 0
        let digits = max(2, String(slices.count).count)
        for (index, slice) in slices.enumerated() {
            let number = String(index + 1).leftPadded(to: digits)
            let url = uniqueURL(in: folder, name: "\(baseName) \(number)")
            do {
                try write(slice.image, scale: scale, to: url)
                written += 1
            } catch {
                Log.editor.error("Failed to write slice \(index + 1): \(String(describing: error), privacy: .public)")
            }
        }
        return written
    }

    private static func uniqueURL(in folder: URL, name: String) -> URL {
        var candidate = folder.appendingPathComponent(name).appendingPathExtension("png")
        var attempt = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) (\(attempt))").appendingPathExtension("png")
            attempt += 1
        }
        return candidate
    }
}

extension String {
    fileprivate func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
