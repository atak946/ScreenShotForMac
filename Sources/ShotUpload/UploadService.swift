import AppKit
import Foundation
import ShotCore

/// Uploads captures to the destination chosen in Settings > Upload.
@MainActor
public final class UploadService: Uploading {
    private let store: UploadSettingsStore

    public init() {
        store = .shared
    }

    public init(store: UploadSettingsStore) {
        self.store = store
    }

    /// Current behavior preferences (copy link, open in browser).
    public var preferences: UploadPreferences { store.preferences }

    public var isConfigured: Bool {
        do {
            try validateActiveDestination()
            return true
        } catch {
            return false
        }
    }

    public func upload(_ payload: UploadPayload) async throws -> UploadResult {
        let preferences = store.preferences
        let keepOriginal = preferences.keepOriginalFilename
        let url: URL
        switch preferences.destination {
        case .none:
            throw UploadError.notConfigured
        case .s3:
            url = try await S3Uploader(resolved: store.resolvedS3(), keepOriginalFilename: keepOriginal).upload(payload)
        case .customHTTP:
            url = try await CustomHTTPUploader(resolved: store.resolvedCustomHTTP(), keepOriginalFilename: keepOriginal)
                .upload(payload)
        }
        return UploadResult(url: url, destinationName: Self.displayName(for: preferences.destination))
    }

    /// Uploads a tiny 1×1 PNG to the active destination.
    public func testConnection() async throws -> UploadResult {
        try validateActiveDestination()
        let payload = UploadPayload(data: Self.testPNG, filename: "screenshotformac-test.png", contentType: "image/png")
        return try await upload(payload)
    }

    /// Uploads, then applies "copy link" / "open in browser" preferences.
    @discardableResult
    public func uploadAndShare(_ payload: UploadPayload) async throws -> UploadResult {
        let result = try await upload(payload)
        applyAfterUploadActions(to: result)
        return result
    }

    /// Copies / opens `result.url` according to the preferences.
    public func applyAfterUploadActions(to result: UploadResult) {
        let preferences = store.preferences
        if preferences.copyLinkAfterUpload {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.url.absoluteString, forType: .string)
        }
        if preferences.openInBrowserAfterUpload {
            NSWorkspace.shared.open(result.url)
        }
    }

    public static func displayName(for kind: UploadDestinationKind) -> String {
        switch kind {
        case .none: String(localized: "None", bundle: .module)
        case .s3: String(localized: "S3-compatible", bundle: .module)
        case .customHTTP: String(localized: "Custom HTTP", bundle: .module)
        }
    }

    private func validateActiveDestination() throws {
        switch store.preferences.destination {
        case .none: throw UploadError.notConfigured
        case .s3: try UploadValidation.validate(store.resolvedS3())
        case .customHTTP: try UploadValidation.validate(store.resolvedCustomHTTP())
        }
    }

    /// Transparent 1×1 PNG.
    private static let testPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
    ) ?? Data()
}
