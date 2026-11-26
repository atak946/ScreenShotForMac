import CoreGraphics
import Foundation

/// The kind of capture the user requested.
public enum CaptureMode: String, Sendable, CaseIterable, Codable {
    case area
    case window
    case fullscreen
}

/// An immutable screenshot produced by a capture service.
public struct CaptureResult: @unchecked Sendable {
    /// Pixel image at native (backing) resolution.
    public let image: CGImage
    /// Backing scale factor of the source display (2.0 on Retina).
    public let scale: CGFloat
    /// Captured rect in global screen coordinates (points, AppKit bottom-left origin).
    public let screenRect: CGRect
    public let mode: CaptureMode
    public let capturedAt: Date
    /// Localized name of the frontmost / captured application, if known.
    public let sourceAppName: String?

    public init(
        image: CGImage,
        scale: CGFloat,
        screenRect: CGRect,
        mode: CaptureMode,
        capturedAt: Date = Date(),
        sourceAppName: String? = nil
    ) {
        self.image = image
        self.scale = scale
        self.screenRect = screenRect
        self.mode = mode
        self.capturedAt = capturedAt
        self.sourceAppName = sourceAppName
    }

    /// Size in points (image pixels divided by scale).
    public var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}

public enum CaptureError: LocalizedError, Sendable {
    case permissionDenied
    case noDisplay
    case captureFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(
                localized: "Screen Recording permission is required. Enable it in System Settings > Privacy & Security > Screen Recording.",
                bundle: .module
            )
        case .noDisplay:
            return String(localized: "No display available to capture.", bundle: .module)
        case let .captureFailed(reason):
            return String(localized: "Capture failed: \(reason)", bundle: .module)
        }
    }
}
