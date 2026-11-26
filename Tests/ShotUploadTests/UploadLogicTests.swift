import Foundation
import ShotCore
@testable import ShotUpload
import Testing

private func isInvalidConfiguration(_ error: any Error) -> Bool {
    if case UploadError.invalidConfiguration = error {
        return true
    }
    return false
}

private func s3(_ configure: (inout S3Configuration) -> Void, secret: String = "secret") -> ResolvedS3Configuration {
    var config = S3Configuration()
    config.endpoint = "https://s3.eu-central-1.amazonaws.com"
    config.bucket = "shots"
    config.accessKeyID = "AKIDEXAMPLE"
    configure(&config)
    return ResolvedS3Configuration(config: config, secretAccessKey: secret)
}

private func custom(
    _ configure: (inout CustomHTTPConfiguration) -> Void,
    headers: [(String, String)] = []
) -> ResolvedCustomHTTPConfiguration {
    var config = CustomHTTPConfiguration()
    config.url = "https://upload.example.com/api"
    configure(&config)
    return ResolvedCustomHTTPConfiguration(config: config, headers: headers.map { (name: $0.0, value: $0.1) })
}

@Suite("ObjectNaming")
struct ObjectNamingTests {
    @Test("Random names keep the lowercased extension")
    func randomNames() {
        let name = ObjectNaming.objectName(for: "Screen Shot.PNG", keepOriginal: false)
        #expect(name.hasSuffix(".png"))
        #expect(name.count == ObjectNaming.randomLength + 4)
        #expect(name.dropLast(4).allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
        #expect(ObjectNaming.objectName(for: "noext", keepOriginal: false).count == ObjectNaming.randomLength)
        #expect(name != ObjectNaming.objectName(for: "Screen Shot.PNG", keepOriginal: false))
    }

    @Test("Original names are sanitized")
    func originalNames() {
        #expect(ObjectNaming.objectName(for: "My Shot (1).png", keepOriginal: true) == "My-Shot-_1_.png")
        #expect(ObjectNaming.objectName(for: "Ekran Görüntüsü.png", keepOriginal: true) == "Ekran-G_r_nt_s_.png")
        #expect(ObjectNaming.objectName(for: ".hidden.", keepOriginal: true) == "hidden")
    }

    @Test("Key prefix expands {date} and normalizes slashes")
    func keys() throws {
        let components = DateComponents(year: 2024, month: 7, day: 9, hour: 12)
        let date = try #require(Calendar.current.date(from: components))
        #expect(ObjectNaming.key(prefix: "shots/{date}/", name: "a.png", date: date) == "shots/2024/07/09/a.png")
        #expect(ObjectNaming.key(prefix: "//a//b//", name: "c.png", date: date) == "a/b/c.png")
        #expect(ObjectNaming.key(prefix: "", name: "c.png", date: date) == "c.png")
    }
}

@Suite("UploadValidation")
struct UploadValidationTests {
    @Test("A complete S3 configuration passes")
    func validS3() throws {
        try UploadValidation.validate(s3 { _ in })
        try UploadValidation.validate(s3 { $0.publicBaseURL = "https://cdn.example.com" })
    }

    @Test(
        "Broken S3 configurations are rejected",
        arguments: [
            s3 { $0.endpoint = "" },
            s3 { $0.endpoint = "ftp://example.com" },
            s3 { $0.endpoint = "not a url" },
            s3 { $0.region = " " },
            s3 { $0.bucket = "" },
            s3 { $0.bucket = "a/b" },
            s3 { $0.bucket = "a b" },
            s3 { $0.accessKeyID = "" },
            s3({ _ in }, secret: ""),
            s3 { $0.publicBaseURL = "cdn.example.com" },
        ]
    )
    func invalidS3(config: ResolvedS3Configuration) {
        #expect(throws: UploadError.self) { try UploadValidation.validate(config) }
        do {
            try UploadValidation.validate(config)
        } catch {
            #expect(isInvalidConfiguration(error))
        }
    }

    @Test("Custom HTTP validation")
    func customHTTP() throws {
        try UploadValidation.validate(custom { _ in })
        try UploadValidation.validate(custom { $0.urlSource = .locationHeader
            $0.urlExpression = ""
        })
        try UploadValidation.validate(custom({ _ in }, headers: [("Authorization", "Bearer x")]))

        let broken = [
            custom { $0.url = "" },
            custom { $0.fileFieldName = " " },
            custom { $0.urlExpression = "" },
            custom { $0.urlSource = .regex
                $0.urlExpression = "([a-z"
            },
            custom({ _ in }, headers: [("Bad:Name", "x")]),
            custom({ _ in }, headers: [("X-Test", "a\nb")]),
        ]
        for config in broken {
            #expect(throws: UploadError.self) { try UploadValidation.validate(config) }
        }
        try UploadValidation.validate(custom { $0.body = .binary
            $0.fileFieldName = ""
        })
    }
}

@Suite("S3 URLs")
struct S3URLTests {
    @Test("Virtual-hosted and path-style object URLs")
    func objectURLs() throws {
        let virtual = try S3Uploader.objectURL(config: s3 { _ in }.config, encodedKey: "2024/a%20b.png")
        #expect(virtual.absoluteString == "https://shots.s3.eu-central-1.amazonaws.com/2024/a%20b.png")

        let path = try S3Uploader.objectURL(
            config: s3 { $0.endpoint = "http://localhost:9000/minio/"
                $0.usePathStyle = true
            }.config, encodedKey: "a.png"
        )
        #expect(path.absoluteString == "http://localhost:9000/minio/shots/a.png")
    }

    @Test("Public base URL replaces the object URL")
    func publicURL() throws {
        let object = try #require(URL(string: "https://shots.s3.amazonaws.com/a.png"))
        let config = s3 { $0.publicBaseURL = "https://cdn.example.com/" }.config
        #expect(try S3Uploader.publicURL(config: config, encodedKey: "x/a.png", objectURL: object).absoluteString
            == "https://cdn.example.com/x/a.png")
        #expect(try S3Uploader.publicURL(config: s3 { _ in }.config, encodedKey: "a.png", objectURL: object) == object)
    }
}

@Suite("ResponseURLExtractor")
struct ResponseURLExtractorTests {
    private func response(status: Int = 200, headers: [String: String] = [:]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://upload.example.com/api"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
    }

    @Test("JSON key paths with nested objects and array indices")
    func jsonPaths() {
        let json = Data(#"{"data":{"link":"https://i.example.com/a.png"},"files":[{"url":"https://f.example.com/0"}],"n":1}"#.utf8)
        #expect(ResponseURLExtractor.jsonValue(at: "data.link", in: json) == "https://i.example.com/a.png")
        #expect(ResponseURLExtractor.jsonValue(at: "files.0.url", in: json) == "https://f.example.com/0")
        #expect(ResponseURLExtractor.jsonValue(at: "files.1.url", in: json) == nil)
        #expect(ResponseURLExtractor.jsonValue(at: "n", in: json) == nil, "non-string values are ignored")
        #expect(ResponseURLExtractor.jsonValue(at: "data", in: Data("not json".utf8)) == nil)
        #expect(ResponseURLExtractor.jsonValue(at: "", in: Data(#""https://x.example.com""#.utf8)) == "https://x.example.com")
    }

    @Test("Regex uses the first capture group when present")
    func regex() {
        let body = "<a href=\"https://i.example.com/abc\">ok</a>"
        #expect(ResponseURLExtractor.regexMatch(#"href="([^"]+)""#, in: body) == "https://i.example.com/abc")
        #expect(ResponseURLExtractor.regexMatch(#"https://\S+?(?=")"#, in: body) == "https://i.example.com/abc")
        #expect(ResponseURLExtractor.regexMatch("nomatch", in: body) == nil)
        #expect(ResponseURLExtractor.regexMatch("([", in: body) == nil)
    }

    @Test("Location header, relative links and failures")
    func extract() throws {
        let location = try ResponseURLExtractor.extract(
            source: .locationHeader, expression: "", data: Data(),
            response: response(status: 201, headers: ["Location": "/files/42"])
        )
        #expect(location.absoluteString == "https://upload.example.com/files/42")

        let json = try ResponseURLExtractor.extract(
            source: .jsonPath, expression: "url", data: Data(#"{"url":" https://x.example.com/1 "}"#.utf8), response: response()
        )
        #expect(json.absoluteString == "https://x.example.com/1")

        #expect(throws: UploadError.self) {
            try ResponseURLExtractor.extract(source: .jsonPath, expression: "missing", data: Data("{}".utf8), response: response())
        }
        #expect(throws: UploadError.self) {
            try ResponseURLExtractor.extract(
                source: .jsonPath, expression: "url", data: Data(#"{"url":"javascript:alert(1)"}"#.utf8), response: response()
            )
        }
    }
}

@Suite("MultipartFormData")
struct MultipartFormDataTests {
    @Test("Body layout and header escaping")
    func encoding() {
        let form = MultipartFormData(fieldName: "fi\"le", filename: "a\r\nb.png", contentType: "image/png", data: Data("PNG".utf8))
        let boundary = form.boundary
        #expect(form.contentTypeHeader == "multipart/form-data; boundary=\(boundary)")
        let expected = "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"fi%22le\"; filename=\"ab.png\"\r\n"
            + "Content-Type: image/png\r\n\r\n"
            + "PNG"
            + "\r\n--\(boundary)--\r\n"
        #expect(String(decoding: form.encoded(), as: UTF8.self) == expected)
        #expect(boundary.hasPrefix("ShotUpload-"))
    }
}

@Suite("UploadPreferences")
struct UploadPreferencesTests {
    @Test("Missing keys decode to defaults")
    func tolerantDecoding() throws {
        let decoded = try JSONDecoder().decode(UploadPreferences.self, from: Data(#"{"destination":"s3"}"#.utf8))
        #expect(decoded.destination == .s3)
        #expect(decoded.copyLinkAfterUpload)
        #expect(!decoded.openInBrowserAfterUpload)
        #expect(!decoded.keepOriginalFilename)
        #expect(try JSONDecoder().decode(UploadPreferences.self, from: Data("{}".utf8)) == UploadPreferences())
    }

    @Test("Round trip")
    func roundTrip() throws {
        var preferences = UploadPreferences()
        preferences.destination = .customHTTP
        preferences.keepOriginalFilename = true
        let data = try JSONEncoder().encode(preferences)
        #expect(try JSONDecoder().decode(UploadPreferences.self, from: data) == preferences)
    }

    @Test("Payload factory encodes PNG and derives MIME types")
    func payloadFactory() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ShotUploadTests-\(UUID().uuidString).mp4")
        try Data([0, 1, 2]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let payload = try UploadPayloadFactory.file(url)
        #expect(payload.contentType == "video/mp4")
        #expect(payload.data == Data([0, 1, 2]))
        #expect(payload.filename == url.lastPathComponent)
    }
}
