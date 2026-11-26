import Foundation
import ShotCore

/// ShareX-style uploader: POST/PUT, custom headers, multipart or raw body, configurable URL extraction.
struct CustomHTTPUploader: Sendable {
    let resolved: ResolvedCustomHTTPConfiguration
    let keepOriginalFilename: Bool

    func upload(_ payload: UploadPayload) async throws -> URL {
        try UploadValidation.validate(resolved)
        let config = resolved.config
        let url = try UploadValidation.httpURL(config.url, field: String(localized: "Request URL", bundle: .module))
        let filename = ObjectNaming.objectName(for: payload.filename, keepOriginal: keepOriginalFilename)

        var request = URLRequest(url: url)
        request.httpMethod = config.method.rawValue
        for header in resolved.headers { request.setValue(header.value, forHTTPHeaderField: header.name) }

        let body: Data
        switch config.body {
        case .multipart:
            let multipart = MultipartFormData(
                fieldName: config.fileFieldName.trimmingCharacters(in: .whitespaces),
                filename: filename,
                contentType: payload.contentType,
                data: payload.data
            )
            body = multipart.encoded()
            request.setValue(multipart.contentTypeHeader, forHTTPHeaderField: "Content-Type")
        case .binary:
            body = payload.data
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue(payload.contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await UploadTransport.send(request, body: body)
        let link = try ResponseURLExtractor.extract(
            source: config.urlSource,
            expression: config.urlExpression,
            data: data,
            response: response
        )
        Log.export.info("Uploaded \(payload.data.count, privacy: .public) bytes to custom HTTP destination")
        return link
    }
}

/// Single-file `multipart/form-data` body.
struct MultipartFormData: Sendable {
    let fieldName: String
    let filename: String
    let contentType: String
    let data: Data
    let boundary = "ShotUpload-\(UUID().uuidString)"

    var contentTypeHeader: String { "multipart/form-data; boundary=\(boundary)" }

    func encoded() -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"\(Self.escape(fieldName))\"; filename=\"\(Self.escape(filename))\"\r\n".utf8
        ))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\"", with: "%22")
    }
}

/// Pulls the shareable link out of an upload response.
enum ResponseURLExtractor {
    static func extract(source: ResponseURLSource, expression: String, data: Data, response: HTTPURLResponse) throws -> URL {
        let candidate: String? = switch source {
        case .jsonPath:
            jsonValue(at: expression, in: data)
        case .regex:
            regexMatch(expression, in: String(decoding: data, as: UTF8.self))
        case .locationHeader:
            response.value(forHTTPHeaderField: "Location")
        }
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            throw UploadError.server(
                status: response.statusCode,
                message: String(localized: "The response did not contain a link.", bundle: .module)
            )
        }
        guard let url = URL(string: trimmed, relativeTo: response.url)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw UploadError.server(
                status: response.statusCode,
                message: String(localized: "The response link is not a valid URL.", bundle: .module)
            )
        }
        return url
    }

    /// Dot-separated key path; numeric components index arrays (e.g. `files.0.url`).
    static func jsonValue(at path: String, in data: Data) -> String? {
        guard var current = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        let components = path.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        for component in components {
            if let dictionary = current as? [String: Any], let next = dictionary[component] {
                current = next
            } else if let array = current as? [Any], let index = Int(component), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current as? String
    }

    /// First capture group if present, otherwise the whole match.
    static func regexMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard let swiftRange = Range(groupRange, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
