import AppKit
import CoreGraphics
import Foundation

// MARK: - Upload (implemented in ShotUpload)

/// A file ready to be uploaded.
public struct UploadPayload: Sendable {
    public let data: Data
    public let filename: String
    /// MIME type, e.g. "image/png", "video/mp4".
    public let contentType: String

    public init(data: Data, filename: String, contentType: String) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}

public struct UploadResult: Sendable {
    /// Public / shareable URL of the uploaded file.
    public let url: URL
    public let destinationName: String
    public init(url: URL, destinationName: String) {
        self.url = url
        self.destinationName = destinationName
    }
}

public enum UploadError: LocalizedError, Sendable {
    case notConfigured
    case invalidConfiguration(String)
    case server(status: Int, message: String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "No upload destination is configured. Set one up in Settings > Upload.", bundle: .module)
        case let .invalidConfiguration(reason):
            return String(localized: "Upload settings are invalid: \(reason)", bundle: .module)
        case let .server(status, message):
            return String(localized: "Upload failed (\(status)): \(message)", bundle: .module)
        case let .network(reason):
            return String(localized: "Upload failed: \(reason)", bundle: .module)
        }
    }
}

@MainActor
public protocol Uploading: AnyObject {
    /// Whether an active destination is configured.
    var isConfigured: Bool { get }
    /// Uploads to the active destination (S3-compatible or custom HTTP).
    func upload(_ payload: UploadPayload) async throws -> UploadResult
}

// MARK: - Sensitive data (implemented in ShotTools)

public enum SensitiveKind: String, Sendable, CaseIterable, Codable {
    case email
    case phone
    case creditCard
    case iban
    case ipAddress
    case url
    case apiKey
    case jwt
}

public struct SensitiveRegion: Sendable, Equatable {
    public let kind: SensitiveKind
    /// Rect in image pixel coordinates (top-left origin).
    public let pixelRect: CGRect
    public let text: String
    public init(kind: SensitiveKind, pixelRect: CGRect, text: String) {
        self.kind = kind
        self.pixelRect = pixelRect
        self.text = text
    }
}

@MainActor
public protocol SensitiveDataDetecting: AnyObject {
    /// Runs OCR + pattern matching; returns regions to redact.
    func detect(in image: CGImage, kinds: Set<SensitiveKind>) async throws -> [SensitiveRegion]
}
