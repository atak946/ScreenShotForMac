import Foundation

/// Which destination receives uploads.
public enum UploadDestinationKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case s3
    case customHTTP

    public var id: String { rawValue }
}

/// User-facing upload behavior plus the active destination.
public struct UploadPreferences: Codable, Sendable, Equatable {
    public var destination: UploadDestinationKind = .none
    /// Copy the returned link to the clipboard after a successful upload.
    public var copyLinkAfterUpload = true
    /// Open the returned link in the default browser after a successful upload.
    public var openInBrowserAfterUpload = false
    /// Keep the original file name instead of a random 10-character name.
    public var keepOriginalFilename = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UploadPreferences()
        destination = try container.decodeIfPresent(UploadDestinationKind.self, forKey: .destination) ?? defaults.destination
        copyLinkAfterUpload = try container.decodeIfPresent(Bool.self, forKey: .copyLinkAfterUpload) ?? defaults.copyLinkAfterUpload
        openInBrowserAfterUpload = try container.decodeIfPresent(Bool.self, forKey: .openInBrowserAfterUpload)
            ?? defaults.openInBrowserAfterUpload
        keepOriginalFilename = try container.decodeIfPresent(Bool.self, forKey: .keepOriginalFilename) ?? defaults.keepOriginalFilename
    }
}

/// Non-secret S3-compatible settings. The secret access key lives in the Keychain.
public struct S3Configuration: Codable, Sendable, Equatable {
    /// e.g. `https://s3.eu-central-1.amazonaws.com`, `https://<account>.r2.cloudflarestorage.com`.
    public var endpoint = ""
    /// e.g. `us-east-1`; Cloudflare R2 uses `auto`.
    public var region = "us-east-1"
    public var bucket = ""
    public var accessKeyID = ""
    /// Optional key prefix; `{date}` expands to `yyyy/MM/dd`.
    public var pathPrefix = ""
    /// Optional custom domain / CDN used to build the returned link.
    public var publicBaseURL = ""
    /// `endpoint/bucket/key` instead of `bucket.endpoint/key` (MinIO, most self-hosted servers).
    public var usePathStyle = false
    /// Sends `x-amz-acl: public-read` (not supported by R2).
    public var publicReadACL = false

    public init() {}
}

/// One HTTP header of a custom destination. Secret values are stored in the Keychain.
public struct UploadHeader: Codable, Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var name = ""
    /// Empty when `isSecret` is true; the value is in the Keychain under `id`.
    public var value = ""
    public var isSecret = false

    public init(name: String = "", value: String = "", isSecret: Bool = false) {
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }
}

public enum CustomHTTPMethod: String, Codable, Sendable, CaseIterable, Identifiable {
    case post = "POST"
    case put = "PUT"
    public var id: String { rawValue }
}

public enum CustomHTTPBody: String, Codable, Sendable, CaseIterable, Identifiable {
    case multipart
    case binary
    public var id: String { rawValue }
}

public enum ResponseURLSource: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Dot-separated JSON key path, e.g. `data.link` or `files.0.url`.
    case jsonPath
    /// First capture group (or whole match) of a regular expression over the body.
    case regex
    /// The `Location` response header.
    case locationHeader
    public var id: String { rawValue }
}

/// ShareX-style custom uploader settings.
public struct CustomHTTPConfiguration: Codable, Sendable, Equatable {
    public var method: CustomHTTPMethod = .post
    public var url = ""
    public var headers: [UploadHeader] = []
    public var body: CustomHTTPBody = .multipart
    public var fileFieldName = "file"
    public var urlSource: ResponseURLSource = .jsonPath
    /// Key path or regex depending on `urlSource`.
    public var urlExpression = "url"

    public init() {}
}

/// Everything the uploaders need, with secrets resolved.
struct ResolvedS3Configuration: Sendable {
    let config: S3Configuration
    let secretAccessKey: String
}

struct ResolvedCustomHTTPConfiguration: Sendable {
    let config: CustomHTTPConfiguration
    /// Final header values (secrets merged in).
    let headers: [(name: String, value: String)]
}
