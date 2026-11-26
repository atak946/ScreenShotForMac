import Foundation
import ShotCore

/// Pre-flight validation; throws `UploadError.invalidConfiguration` with a localized reason.
enum UploadValidation {
    static func validate(_ resolved: ResolvedS3Configuration) throws {
        let config = resolved.config
        _ = try httpURL(config.endpoint, field: String(localized: "Endpoint URL", bundle: .module))
        if isBlank(config.region) { throw missing(String(localized: "Region", bundle: .module)) }
        if isBlank(config.bucket) { throw missing(String(localized: "Bucket", bundle: .module)) }
        if config.bucket.contains("/") || config.bucket.contains(" ") {
            throw UploadError.invalidConfiguration(String(localized: "Bucket name must not contain slashes or spaces.", bundle: .module))
        }
        if isBlank(config.accessKeyID) { throw missing(String(localized: "Access Key ID", bundle: .module)) }
        if resolved.secretAccessKey.isEmpty { throw missing(String(localized: "Secret Access Key", bundle: .module)) }
        if !isBlank(config.publicBaseURL) {
            _ = try httpURL(config.publicBaseURL, field: String(localized: "Public URL", bundle: .module))
        }
    }

    static func validate(_ resolved: ResolvedCustomHTTPConfiguration) throws {
        let config = resolved.config
        _ = try httpURL(config.url, field: String(localized: "Request URL", bundle: .module))
        if config.body == .multipart, isBlank(config.fileFieldName) {
            throw missing(String(localized: "File field name", bundle: .module))
        }
        switch config.urlSource {
        case .jsonPath:
            if isBlank(config.urlExpression) { throw missing(String(localized: "JSON key path", bundle: .module)) }
        case .regex:
            if isBlank(config.urlExpression) { throw missing(String(localized: "Regular expression", bundle: .module)) }
            if (try? NSRegularExpression(pattern: config.urlExpression)) == nil {
                throw UploadError.invalidConfiguration(String(localized: "The regular expression is not valid.", bundle: .module))
            }
        case .locationHeader:
            break
        }
        for header in resolved.headers where header.name.contains(":") || header.value.contains("\n") {
            throw UploadError.invalidConfiguration(String(localized: "Header \"\(header.name)\" is not valid.", bundle: .module))
        }
    }

    /// Parses an absolute http(s) URL with a host.
    static func httpURL(_ string: String, field: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw missing(field) }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host(percentEncoded: false)?.isEmpty == false else {
            throw UploadError.invalidConfiguration(String(localized: "\(field) must be a valid http(s) URL.", bundle: .module))
        }
        return url
    }

    private static func isBlank(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func missing(_ field: String) -> UploadError {
        .invalidConfiguration(String(localized: "\(field) is required.", bundle: .module))
    }
}
