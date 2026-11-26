import Foundation
@testable import ShotUpload
import Testing

/// Official example requests from the AWS S3 "Signature Version 4: Authenticating Requests
/// (AWS Signature Version 4) — Header-based auth" documentation. Credentials are AWS's public examples.
@Suite("AWSSignatureV4")
struct AWSSignatureV4Tests {
    private static let emptyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    private let signer = AWSSignatureV4(
        accessKeyID: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1"
    )
    /// 2013-05-24T00:00:00Z
    private let date = Date(timeIntervalSince1970: 1_369_353_600)

    private func signature(from headers: [String: String]) -> String? {
        headers["authorization"]?.components(separatedBy: "Signature=").last
    }

    @Test("GET Object example")
    func getObject() throws {
        let url = try #require(URL(string: "https://examplebucket.s3.amazonaws.com/test.txt"))
        let headers = signer.sign(
            method: "GET", url: url, headers: ["Range": "bytes=0-9"], payloadHash: Self.emptyHash, date: date
        )
        #expect(
            headers["authorization"]
                == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, "
                + "SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, "
                + "Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
        )
        #expect(headers["x-amz-date"] == "20130524T000000Z")
        #expect(headers["x-amz-content-sha256"] == Self.emptyHash)
        #expect(headers["host"] == nil, "URLSession sets Host itself")
        #expect(headers["range"] == "bytes=0-9")
    }

    @Test("PUT Object example (encoded key, extra signed headers)")
    func putObject() throws {
        let body = Data("Welcome to Amazon S3.".utf8)
        let payloadHash = AWSSignatureV4.sha256Hex(body)
        #expect(payloadHash == "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072")
        let url = try #require(URL(string: "https://examplebucket.s3.amazonaws.com/test%24file.text"))
        let headers = signer.sign(
            method: "PUT",
            url: url,
            headers: ["Date": "Fri, 24 May 2013 00:00:00 GMT", "x-amz-storage-class": "REDUCED_REDUNDANCY"],
            payloadHash: payloadHash,
            date: date
        )
        #expect(signature(from: headers) == "98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd")
        #expect(headers["authorization"]?.contains("SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class") == true)
    }

    @Test("GET Bucket Lifecycle example (valueless query parameter)")
    func getLifecycle() throws {
        let url = try #require(URL(string: "https://examplebucket.s3.amazonaws.com/?lifecycle"))
        let headers = signer.sign(method: "GET", url: url, headers: [:], payloadHash: Self.emptyHash, date: date)
        #expect(signature(from: headers) == "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543")
    }

    @Test("GET Bucket (List Objects) example (sorted query parameters)")
    func listObjects() throws {
        let url = try #require(URL(string: "https://examplebucket.s3.amazonaws.com/?prefix=J&max-keys=2"))
        let headers = signer.sign(method: "GET", url: url, headers: [:], payloadHash: Self.emptyHash, date: date)
        #expect(signature(from: headers) == "34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7")
    }

    @Test("Signing is deterministic and header-case-insensitive")
    func deterministic() throws {
        let url = try #require(URL(string: "https://examplebucket.s3.amazonaws.com/a/b.png"))
        let one = signer.sign(method: "PUT", url: url, headers: ["Content-Type": "image/png"], payloadHash: Self.emptyHash, date: date)
        let two = signer.sign(method: "PUT", url: url, headers: ["content-type": "  image/png "], payloadHash: Self.emptyHash, date: date)
        #expect(one == two)
        let later = signer.sign(
            method: "PUT", url: url, headers: ["content-type": "image/png"], payloadHash: Self.emptyHash, date: date.addingTimeInterval(1)
        )
        #expect(signature(from: later) != signature(from: one))
    }

    @Test("URI encoding and host header")
    func helpers() throws {
        #expect(AWSSignatureV4.uriEncode("a b/c+d~e", keepSlash: true) == "a%20b/c%2Bd~e")
        #expect(AWSSignatureV4.uriEncode("a/b", keepSlash: false) == "a%2Fb")
        #expect(AWSSignatureV4.uriEncode("ğ", keepSlash: false) == "%C4%9F")
        #expect(try AWSSignatureV4.hostHeader(for: #require(URL(string: "https://s3.example.com:443/x"))) == "s3.example.com")
        #expect(try AWSSignatureV4.hostHeader(for: #require(URL(string: "http://localhost:9000/x"))) == "localhost:9000")
    }
}
