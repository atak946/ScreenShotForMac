import CryptoKit
import Foundation

/// AWS Signature Version 4 for a single S3 request (header-based auth, signed payload hash).
struct AWSSignatureV4: Sendable {
    static let algorithm = "AWS4-HMAC-SHA256"
    static let service = "s3"

    let accessKeyID: String
    let secretAccessKey: String
    let region: String

    /// Returns the headers to add (including `Authorization`, `x-amz-date`, `x-amz-content-sha256`).
    /// `headers` are the other headers that must be signed (e.g. `content-type`, `x-amz-acl`).
    func sign(
        method: String,
        url: URL,
        headers: [String: String],
        payloadHash: String,
        date: Date = Date()
    ) -> [String: String] {
        let stamps = Self.timestamps(for: date)
        var signed = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), Self.trimmed($0.value)) })
        signed["host"] = Self.hostHeader(for: url)
        signed["x-amz-date"] = stamps.amzDate
        signed["x-amz-content-sha256"] = payloadHash

        let signedHeaderNames = signed.keys.sorted()
        let canonicalHeaders = signedHeaderNames.map { "\($0):\(signed[$0] ?? "")\n" }.joined()
        let signedHeaders = signedHeaderNames.joined(separator: ";")
        let canonicalRequest = [
            method,
            Self.canonicalURI(for: url),
            Self.canonicalQuery(for: url),
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        let scope = "\(stamps.day)/\(region)/\(Self.service)/aws4_request"
        let stringToSign = [
            Self.algorithm,
            stamps.amzDate,
            scope,
            Self.sha256Hex(Data(canonicalRequest.utf8)),
        ].joined(separator: "\n")

        let signature = Self.hex(HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: signingKey(day: stamps.day)
        ))
        var result = signed
        result.removeValue(forKey: "host")
        result["authorization"] =
            "\(Self.algorithm) Credential=\(accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        return result
    }

    // MARK: Helpers

    static func sha256Hex(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    /// RFC 3986 percent-encoding (unreserved characters kept); `/` kept when `keepSlash`.
    static func uriEncode(_ string: String, keepSlash: Bool) -> String {
        var allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        if keepSlash { allowed.insert("/") }
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func signingKey(day: String) -> SymmetricKey {
        let secret = SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8))
        let dateKey = Self.hmac(secret, day)
        let regionKey = Self.hmac(dateKey, region)
        let serviceKey = Self.hmac(regionKey, Self.service)
        return Self.hmac(serviceKey, "aws4_request")
    }

    private static func hmac(_ key: SymmetricKey, _ message: String) -> SymmetricKey {
        SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)))
    }

    private static func hex(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func timestamps(for date: Date) -> (amzDate: String, day: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = formatter.string(from: date)
        return (amzDate, String(amzDate.prefix(8)))
    }

    static func hostHeader(for url: URL) -> String {
        let host = url.host(percentEncoded: false) ?? ""
        guard let port = url.port else { return host }
        let isDefault = (url.scheme == "https" && port == 443) || (url.scheme == "http" && port == 80)
        return isDefault ? host : "\(host):\(port)"
    }

    /// The URL path is already percent-encoded by the caller; S3 does not double-encode.
    private static func canonicalURI(for url: URL) -> String {
        let path = url.path(percentEncoded: true)
        return path.isEmpty ? "/" : path
    }

    private static func canonicalQuery(for url: URL) -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return "" }
        let pairs: [(name: String, value: String)] = items.map { item in
            (uriEncode(item.name, keepSlash: false), uriEncode(item.value ?? "", keepSlash: false))
        }
        let sorted = pairs.sorted { lhs, rhs in
            lhs.name == rhs.name ? lhs.value < rhs.value : lhs.name < rhs.name
        }
        return sorted.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }

    private static func trimmed(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
