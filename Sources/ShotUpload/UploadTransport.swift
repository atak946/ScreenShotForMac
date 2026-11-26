import Foundation
import ShotCore

/// Shared URLSession and HTTP → `UploadError` mapping.
enum UploadTransport {
    static let timeout: TimeInterval = 60
    static let maxMessageLength = 200

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 5
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    /// Sends `request` with `body`; throws `.server` for non-2xx responses and `.network` for transport errors.
    static func send(_ request: URLRequest, body: Data) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.timeoutInterval = timeout
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch let error as URLError {
            Log.export.error("Upload transport error: \(error.localizedDescription, privacy: .public)")
            throw UploadError.network(error.localizedDescription)
        } catch {
            throw UploadError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.network(String(localized: "The server returned an invalid response.", bundle: .module))
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = serverMessage(from: data, status: http.statusCode)
            Log.export.error("Upload rejected with status \(http.statusCode, privacy: .public)")
            throw UploadError.server(status: http.statusCode, message: message)
        }
        return (data, http)
    }

    /// Body text trimmed to `maxMessageLength`; S3 XML errors are reduced to their `<Message>`.
    static func serverMessage(from data: Data, status: Int) -> String {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let extracted = xmlValue("Message", in: text) ?? text
        guard !extracted.isEmpty else {
            return HTTPURLResponse.localizedString(forStatusCode: status)
        }
        guard extracted.count > maxMessageLength else { return extracted }
        return String(extracted.prefix(maxMessageLength)) + "…"
    }

    private static func xmlValue(_ tag: String, in text: String) -> String? {
        guard let start = text.range(of: "<\(tag)>"),
              let end = text.range(of: "</\(tag)>", range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.upperBound..<end.lowerBound])
    }
}
