import Foundation
import ShotCore
@testable import ShotWorkflow
import Testing

private func parse(_ string: String) -> AutomationRequest? {
    URL(string: string).flatMap(AutomationURL.parse)
}

@Suite("AutomationURL")
struct AutomationURLTests {
    @Test(
        "Capture routes",
        arguments: [
            ("ssfm://capture", AutomationRequest.capture(mode: .area, action: nil, delay: 0)),
            ("ssfm://capture?mode=window&action=copy", .capture(mode: .window, action: .copy, delay: 0)),
            ("SSFM://CAPTURE?MODE=FULLSCREEN&ACTION=PIN&DELAY=5", .capture(mode: .fullscreen, action: .pin, delay: 5)),
            ("ssfm://capture?mode=area&delay=99", .capture(mode: .area, action: nil, delay: 30)),
            ("ssfm://capture?delay=-3", .capture(mode: .area, action: nil, delay: 0)),
            ("ssfm://capture?delay=abc", .capture(mode: .area, action: nil, delay: 0)),
            ("ssfm://capture?mode=area&mode=window", .capture(mode: .area, action: nil, delay: 0)),
            ("ssfm://capture?mode=scrolling", .scrollingCapture),
            ("ssfm://capture?mode=last", .command(.captureLastArea)),
            ("ssfm://capture?mode=previous", .command(.captureLastArea)),
        ]
    )
    func capture(url: String, expected: AutomationRequest) {
        #expect(parse(url) == expected)
    }

    @Test(
        "Simple command routes",
        arguments: [
            ("ssfm://ocr", AppCommand.recognizeText),
            ("ssfm://color", .pickColor),
            ("ssfm://qr", .scanQRCode),
            ("ssfm://measure", .measure),
            ("ssfm://history", .showHistory),
            ("ssfm://settings", .openSettings),
        ]
    )
    func commands(url: String, expected: AppCommand) {
        #expect(parse(url) == .command(expected))
    }

    @Test("Record, workflow and open routes")
    func otherRoutes() {
        #expect(parse("ssfm://record") == .record(.mp4))
        #expect(parse("ssfm://record?format=GIF") == .record(.gif))
        let id = UUID()
        #expect(parse("ssfm://workflow?id=\(id.uuidString)") == .runWorkflow(.id(id)))
        #expect(parse("ssfm://workflow?name=%20Upload%20it%20") == .runWorkflow(.name("Upload it")))
        #expect(parse("ssfm://open?path=/tmp/a/../b.png") == .openFile(URL(fileURLWithPath: "/tmp/b.png")))
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(parse("ssfm://open?path=~/x.png") == .openFile(URL(fileURLWithPath: home + "/x.png").standardizedFileURL))
    }

    @Test("Backdrop and combine routes")
    func backdropAndCombine() {
        #expect(parse("ssfm://backdrop?path=/tmp/a.png") == .backdropFile(URL(fileURLWithPath: "/tmp/a.png")))
        #expect(parse("ssfm://BACKDROP?PATH=/tmp/x/../a.png") == .backdropFile(URL(fileURLWithPath: "/tmp/a.png")))
        #expect(parse("ssfm://combine?path=/tmp/a.png&path=/tmp/b.png") == .combineFiles([
            URL(fileURLWithPath: "/tmp/a.png"), URL(fileURLWithPath: "/tmp/b.png"),
        ]))
        #expect(parse("ssfm://combine?path=/tmp/only.png") == .combineFiles([URL(fileURLWithPath: "/tmp/only.png")]))
    }

    @Test(
        "Invalid URLs are rejected",
        arguments: [
            "https://capture",
            "ssfm://",
            "ssfm://unknown",
            "ssfm://capture?mode=bogus",
            "ssfm://capture?action=delete",
            "ssfm://record?format=avi",
            "ssfm://workflow",
            "ssfm://workflow?id=not-a-uuid",
            "ssfm://workflow?name=%20%20",
            "ssfm://open",
            "ssfm://open?path=relative/file.png",
            "ssfm://backdrop",
            "ssfm://backdrop?path=relative.png",
            "ssfm://combine",
            "ssfm://combine?path=/tmp/a.png&path=relative.png",
            "ssfm://combine?path=",
        ]
    )
    func invalid(url: String) {
        #expect(parse(url) == nil)
    }

    @Test("Builders round-trip through the parser")
    func builders() throws {
        let capture = try #require(AutomationURL.captureURL(mode: .window, action: .upload, delay: 3))
        #expect(AutomationURL.parse(capture) == .capture(mode: .window, action: .upload, delay: 3))
        let plain = try #require(AutomationURL.captureURL(mode: .area, action: nil))
        #expect(plain.absoluteString == "ssfm://capture?mode=area")
        #expect(try AutomationURL.parse(#require(AutomationURL.scrollingCaptureURL())) == .scrollingCapture)
        let id = UUID()
        #expect(try AutomationURL.parse(#require(AutomationURL.workflowURL(.id(id)))) == .runWorkflow(.id(id)))
        #expect(try AutomationURL.parse(#require(AutomationURL.workflowURL(.name("Ä & B?")))) == .runWorkflow(.name("Ä & B?")))
        #expect(try AutomationURL.parse(#require(AutomationURL.commandURL("ocr"))) == .command(.recognizeText))
    }
}

@Suite("Workflow model")
struct WorkflowModelTests {
    private let sample = Workflow(
        name: "All steps",
        symbol: "star",
        captureMode: .window,
        delaySeconds: 5,
        steps: [
            .annotateInEditor, .autoRedactSensitive, .applyBackdropPreset(name: "Ocean"), .downscaleTo1x,
            .copyImage, .saveToFolder(bookmark: Data([9, 8, 7])), .saveToFolder(bookmark: nil), .upload,
            .copyUploadLink, .ocrCopyText, .pin, .showQuickAccess, .openWith(appBundleID: "com.apple.Preview"),
            .runShortcut(name: "Resize"), .playSound,
        ]
    )

    @Test("Codable round trip keeps every step and payload")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode([sample])
        let decoded = try JSONDecoder().decode([Workflow].self, from: data)
        #expect(decoded == [sample])
    }

    @Test("Delay is clamped on init")
    func clampDelay() {
        #expect(Workflow(name: "a", delaySeconds: 99).delaySeconds == Workflow.maxDelaySeconds)
        #expect(Workflow(name: "a", delaySeconds: -1).delaySeconds == 0)
    }

    @Test("Duplicates get a new id and name")
    func duplicate() {
        let copy = sample.duplicated(named: "Copy")
        #expect(copy.id != sample.id)
        #expect(copy.name == "Copy")
        #expect(copy.steps == sample.steps)
        #expect(copy.captureMode == sample.captureMode)
    }

    @Test("Step kinds and default steps agree", arguments: WorkflowStepKind.allCases)
    func stepKinds(kind: WorkflowStepKind) {
        #expect(kind.defaultStep.kind == kind)
    }

    @Test("Built-in examples have fixed unique ids")
    func builtIns() {
        let all = BuiltInWorkflows.all
        #expect(all.count == 3)
        #expect(Set(all.map(\.id)).count == 3)
        #expect(all.map(\.id) == BuiltInWorkflows.all.map(\.id), "ids are stable across calls")
        #expect(all.allSatisfy { !$0.steps.isEmpty && !$0.name.isEmpty })
        #expect(BuiltInWorkflows.windowBackdropSave.captureMode == .window)
    }
}

@MainActor
@Suite("WorkflowStore")
struct WorkflowStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotWorkflowTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Workflows.json")
    }

    @Test("First launch seeds examples; edits persist")
    func persistence() {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkflowStore(fileURL: url)
        #expect(store.workflows.map(\.id) == BuiltInWorkflows.all.map(\.id))
        #expect(FileManager.default.fileExists(atPath: url.path))

        let added = store.add(Workflow(name: "Ünïcode Flow", steps: [.copyImage]))
        store.delete(id: BuiltInWorkflows.redactAndCopy.id)
        let reloaded = WorkflowStore(fileURL: url)
        #expect(reloaded.workflows.count == 3)
        #expect(reloaded.workflow(id: added.id) == added)
        #expect(reloaded.workflow(named: "  unicode flow ")?.id == added.id)
        #expect(reloaded.workflow(matching: added.id.uuidString)?.id == added.id)

        reloaded.restoreExamples()
        #expect(reloaded.workflows.count == 4)
    }

    @Test("Corrupt files fall back to examples and report an error")
    func corruptFile() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ nope".utf8).write(to: url)
        let store = WorkflowStore(fileURL: url)
        #expect(store.workflows.count == BuiltInWorkflows.all.count)
        #expect(store.lastError != nil)
    }

    @Test("Duplicate inserts after the source; move reorders")
    func duplicateAndMove() {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkflowStore(fileURL: url)
        let source = BuiltInWorkflows.uploadAndCopyLink
        let copy = store.duplicate(source)
        #expect(store.workflows[1].id == copy.id)
        store.move(fromOffsets: IndexSet(integer: 1), toOffset: store.workflows.count)
        #expect(store.workflows.last?.id == copy.id)
        var renamed = copy
        renamed.name = "Renamed"
        store.update(renamed)
        #expect(store.workflow(id: copy.id)?.name == "Renamed")
    }
}
