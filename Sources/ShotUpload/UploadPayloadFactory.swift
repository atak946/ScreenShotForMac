import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers

/// Builds `UploadPayload`s from images and files.
public enum UploadPayloadFactory {
    private static let pointsPerInch: CGFloat = 72

    /// PNG-encodes `image`; `scale` (e.g. 2 for Retina) is written as DPI metadata.
    public static func png(_ image: CGImage, scale: CGFloat, filename: String) -> UploadPayload? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            Log.export.error("Upload: failed to create PNG destination")
            return nil
        }
        let dpi = pointsPerInch * max(scale, 1)
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            Log.export.error("Upload: failed to encode PNG")
            return nil
        }
        let base = (filename as NSString).deletingPathExtension
        let name = (base.isEmpty ? "Screenshot" : base) + ".png"
        return UploadPayload(data: data as Data, filename: name, contentType: "image/png")
    }

    /// Reads a file and derives its MIME type from its extension (UTType).
    public static func file(_ url: URL) throws -> UploadPayload {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let type = UTType(filenameExtension: url.pathExtension)
        let mime = type?.preferredMIMEType ?? "application/octet-stream"
        return UploadPayload(data: data, filename: url.lastPathComponent, contentType: mime)
    }
}
