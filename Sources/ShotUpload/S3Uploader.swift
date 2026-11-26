import Foundation
import ShotCore

/// Single signed PUT to an S3-compatible bucket (AWS S3, Cloudflare R2, MinIO, Backblaze B2).
struct S3Uploader: Sendable {
    let resolved: ResolvedS3Configuration
    let keepOriginalFilename: Bool

    func upload(_ payload: UploadPayload) async throws -> URL {
        try UploadValidation.validate(resolved)
        let config = resolved.config
        let name = ObjectNaming.objectName(for: payload.filename, keepOriginal: keepOriginalFilename)
        let key = ObjectNaming.key(prefix: config.pathPrefix, name: name)
        let encodedKey = AWSSignatureV4.uriEncode(key, keepSlash: true)
        let objectURL = try Self.objectURL(config: config, encodedKey: encodedKey)

        let payloadHash = AWSSignatureV4.sha256Hex(payload.data)
        var signedHeaders = ["content-type": payload.contentType]
        if config.publicReadACL { signedHeaders["x-amz-acl"] = "public-read" }
        let signer = AWSSignatureV4(
            accessKeyID: config.accessKeyID.trimmingCharacters(in: .whitespaces),
            secretAccessKey: resolved.secretAccessKey,
            region: config.region.trimmingCharacters(in: .whitespaces)
        )
        let headers = signer.sign(method: "PUT", url: objectURL, headers: signedHeaders, payloadHash: payloadHash)

        var request = URLRequest(url: objectURL)
        request.httpMethod = "PUT"
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        _ = try await UploadTransport.send(request, body: payload.data)
        Log.export.info("Uploaded \(payload.data.count, privacy: .public) bytes to S3-compatible storage")
        return try Self.publicURL(config: config, encodedKey: encodedKey, objectURL: objectURL)
    }

    /// Path-style: `endpoint/bucket/key`; virtual-hosted: `bucket.host/key`.
    static func objectURL(config: S3Configuration, encodedKey: String) throws -> URL {
        let endpoint = try UploadValidation.httpURL(config.endpoint, field: String(localized: "Endpoint URL", bundle: .module))
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let host = components.host else {
            throw UploadError.invalidConfiguration(String(localized: "Endpoint URL must be a valid http(s) URL.", bundle: .module))
        }
        let bucket = AWSSignatureV4.uriEncode(config.bucket.trimmingCharacters(in: .whitespaces), keepSlash: false)
        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.query = nil
        components.fragment = nil
        if config.usePathStyle {
            let segments = [basePath, bucket, encodedKey].filter { !$0.isEmpty }
            components.percentEncodedPath = "/" + segments.joined(separator: "/")
        } else {
            components.host = "\(config.bucket.trimmingCharacters(in: .whitespaces)).\(host)"
            components.percentEncodedPath = "/" + encodedKey
        }
        guard let url = components.url else {
            throw UploadError.invalidConfiguration(String(localized: "Endpoint URL must be a valid http(s) URL.", bundle: .module))
        }
        return url
    }

    static func publicURL(config: S3Configuration, encodedKey: String, objectURL: URL) throws -> URL {
        let base = config.publicBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return objectURL }
        let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: "\(trimmedBase)/\(encodedKey)") else {
            throw UploadError.invalidConfiguration(String(localized: "Public URL must be a valid http(s) URL.", bundle: .module))
        }
        return url
    }
}
