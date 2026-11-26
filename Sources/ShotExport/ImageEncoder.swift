import CoreGraphics
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers

/// Encodes CGImages with ImageIO, embedding DPI so viewers show the correct point size.
enum ImageEncoder {
    static func data(for image: CGImage, format: ImageFormat, quality: Double, scale: CGFloat) throws -> Data {
        let output = NSMutableData()
        let type = utType(for: format).identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else {
            throw ExportError.encodingFailed(format: format.rawValue)
        }
        CGImageDestinationAddImage(destination, image, properties(format: format, quality: quality, scale: scale))
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.encodingFailed(format: format.rawValue)
        }
        return output as Data
    }

    static func pngData(for image: CGImage, scale: CGFloat) throws -> Data {
        try data(for: image, format: .png, quality: 1, scale: scale)
    }

    static func utType(for format: ImageFormat) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }

    private static func properties(format: ImageFormat, quality: Double, scale: CGFloat) -> CFDictionary {
        let dpi = 72.0 * Double(max(scale, 1))
        var props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        switch format {
        case .png:
            props[kCGImagePropertyPNGDictionary] = [
                kCGImagePropertyPNGXPixelsPerMeter: Int((dpi / 0.0254).rounded()),
                kCGImagePropertyPNGYPixelsPerMeter: Int((dpi / 0.0254).rounded()),
            ]
        case .jpeg, .heic:
            props[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        return props as CFDictionary
    }
}
