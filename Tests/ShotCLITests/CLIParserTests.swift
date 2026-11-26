import Foundation
@testable import ShotCLI
import Testing

private func url(_ arguments: [String]) -> String? {
    guard case let .url(url) = CLIParser.parse(arguments) else { return nil }
    return url.absoluteString
}

private func isFailure(_ arguments: [String]) -> Bool {
    if case .failure = CLIParser.parse(arguments) {
        return true
    }
    return false
}

@Suite("CLIParser")
struct CLIParserTests {
    @Test("Help and version")
    func helpAndVersion() {
        #expect(CLIParser.parse([]) == .help)
        for flag in ["-h", "--help", "help"] {
            #expect(CLIParser.parse([flag]) == .help)
        }
        for flag in ["-v", "--version", "version"] {
            #expect(CLIParser.parse([flag]) == .version)
        }
    }

    @Test(
        "Capture arguments",
        arguments: [
            (["capture"], "ssfm://capture?mode=area"),
            (["capture", "window", "--copy"], "ssfm://capture?mode=window&action=copy"),
            (["capture", "--save", "fullscreen", "--delay", "5"], "ssfm://capture?mode=fullscreen&action=save&delay=5"),
            (["capture", "-d", "0"], "ssfm://capture?mode=area"),
            (["capture", "scrolling"], "ssfm://capture?mode=scrolling"),
            (["capture", "last", "--pin"], "ssfm://capture?mode=last&action=pin"),
        ]
    )
    func capture(arguments: [String], expected: String) {
        #expect(url(arguments) == expected)
    }

    @Test(
        "Invalid arguments fail",
        arguments: [
            ["capture", "--copy", "--save"],
            ["capture", "--delay"],
            ["capture", "--delay", "31"],
            ["capture", "--delay", "x"],
            ["capture", "sideways"],
            ["record", "avi"],
            ["record", "mp4", "gif"],
            ["workflow"],
            ["workflow", "  "],
            ["ocr", "extra"],
            ["open"],
            ["open", "/definitely/not/here.png"],
            ["frobnicate"],
        ]
    )
    func failures(arguments: [String]) {
        #expect(isFailure(arguments))
    }

    @Test("Record, workflow and simple commands")
    func otherCommands() {
        #expect(url(["record"]) == "ssfm://record?format=mp4")
        #expect(url(["record", "--gif"]) == "ssfm://record?format=gif")
        #expect(url(["record", "gif"]) == "ssfm://record?format=gif")
        let id = UUID().uuidString
        #expect(url(["workflow", id]) == "ssfm://workflow?id=\(id)")
        #expect(url(["run", "Upload", "and", "copy"]) == "ssfm://workflow?name=Upload%20and%20copy")
        for command in ["ocr", "color", "qr", "measure", "history", "settings"] {
            #expect(url([command]) == "ssfm://\(command)")
        }
    }

    @Test("Open resolves an existing file to an absolute path")
    func openFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ShotCLITests-\(UUID().uuidString).png")
        try Data([1]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        guard case let .url(result) = CLIParser.parse(["open", file.path]) else {
            Issue.record("expected a URL")
            return
        }
        let path = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "path" }?.value
        #expect(path == file.standardizedFileURL.path)
        #expect(isFailure(["open", FileManager.default.temporaryDirectory.path]), "directories are rejected")
    }
}
