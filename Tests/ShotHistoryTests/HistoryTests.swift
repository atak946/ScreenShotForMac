import CoreGraphics
import Foundation
import ShotCore
@testable import ShotHistory
import Testing

private func item(text: String? = nil, app: String? = nil, kind: HistoryItem.Kind = .image, date: Date = Date()) -> HistoryItem {
    let url = URL(fileURLWithPath: "/tmp/x.png")
    return HistoryItem(
        createdAt: date, fileURL: url, thumbnailURL: url, pixelSize: CGSize(width: 1, height: 1), scale: 1,
        sourceAppName: app, kind: kind, recognizedText: text
    )
}

private func record(id: UUID = UUID(), daysAgo: Double, now: Date) -> HistoryRecord {
    HistoryRecord(
        id: id, createdAt: now.addingTimeInterval(-daysAgo * 86400), fileName: "\(id.uuidString).png",
        thumbnailName: "\(id.uuidString).thumb.jpg", pixelWidth: 10, pixelHeight: 20, scale: 2,
        sourceAppName: "Safari", kind: .image, mode: .area, screenRect: CGRect(x: 1, y: 2, width: 3, height: 4),
        recognizedText: nil
    )
}

private final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("ShotHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

@MainActor
@Suite("HistorySearch")
struct HistorySearchTests {
    private let items = [
        item(text: "Invoice Number 42\nTotal: 1.250 ₺", app: "Preview"),
        item(text: "Çalışma planı ve görevler", app: "Notes"),
        item(text: nil, app: "Safari", kind: .video),
    ]

    @Test("Empty and whitespace queries return everything")
    func emptyQuery() {
        #expect(HistorySearch.filter(items, query: "").count == 3)
        #expect(HistorySearch.filter(items, query: "   \n").count == 3)
    }

    @Test("Case and diacritic insensitive matching")
    func insensitive() {
        #expect(HistorySearch.filter(items, query: "INVOICE").map(\.recognizedText) == [items[0].recognizedText])
        #expect(HistorySearch.filter(items, query: "calışma gorev").map(\.sourceAppName) == ["Notes"])
        #expect(HistorySearch.filter(items, query: "GÖREVLER").count == 1)
    }

    @Test("Every term must match, across text, app and kind")
    func multiToken() {
        #expect(HistorySearch.filter(items, query: "invoice preview").count == 1)
        #expect(HistorySearch.filter(items, query: "invoice notes").isEmpty)
        #expect(HistorySearch.filter(items, query: "safari video").map(\.kind) == [.video])
    }

    @Test("Dates are searchable in ISO form")
    func dates() throws {
        let date = try #require(Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 2, hour: 9, minute: 5)))
        let dated = [item(text: "x", date: date), item(text: "y")]
        #expect(HistorySearch.filter(dated, query: "2023-11-02").map(\.recognizedText) == ["x"])
        #expect(HistorySearch.filter(dated, query: "2023-11-02 09:05").count == 1)
    }

    @Test("Normalization folds case, diacritics and width")
    func normalize() {
        #expect(HistorySearch.normalize("ÉLAN") == HistorySearch.normalize("elan"))
        #expect(HistorySearch.normalize("ＡＢＣ") == HistorySearch.normalize("abc"))
    }
}

@Suite("HistoryRetention")
struct HistoryRetentionTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Only records older than the retention window expire")
    func expired() {
        let old = record(daysAgo: 31, now: now)
        let edge = record(daysAgo: 29.9, now: now)
        let fresh = record(daysAgo: 1, now: now)
        let result = HistoryRetention.expired([old, edge, fresh], retentionDays: 30, now: now)
        #expect(result == [old])
        #expect(HistoryRetention.expired([old], retentionDays: 0, now: now).isEmpty, "0 keeps forever")
        #expect(HistoryRetention.expired([old], retentionDays: -1, now: now).isEmpty)
        #expect(HistoryRetention.expired([fresh], retentionDays: 1, now: now.addingTimeInterval(1)) == [fresh])
    }

    @Test("Orphans are unreferenced UUID-named files")
    func orphans() throws {
        let directory = try TemporaryDirectory()
        let referenced = "\(UUID().uuidString).png"
        let orphan = "\(UUID().uuidString).png"
        for name in [referenced, orphan, "notes.txt", HistoryIndexFile.fileName] {
            try Data().write(to: directory.url.appendingPathComponent(name))
        }
        let result = HistoryRetention.orphanFiles(in: directory.url, referenced: [referenced]).map(\.lastPathComponent)
        #expect(result == [orphan])
    }

    @Test("Deletes refuse files outside the history root")
    func deleteSafety() throws {
        let directory = try TemporaryDirectory()
        let inside = directory.url.appendingPathComponent("a.png")
        try Data().write(to: inside)
        try HistoryRetention.deleteFile(inside, root: directory.url)
        #expect(!FileManager.default.fileExists(atPath: inside.path))
        try HistoryRetention.deleteFile(inside, root: directory.url) // missing file is fine

        let subfolder = directory.url.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        let nested = subfolder.appendingPathComponent("b.png")
        try Data().write(to: nested)
        #expect(throws: HistoryError.self) { try HistoryRetention.deleteFile(nested, root: directory.url) }
        let escape = directory.url.appendingPathComponent("sub/../../outside.png")
        #expect(throws: HistoryError.self) { try HistoryRetention.deleteFile(escape, root: directory.url) }
        #expect(FileManager.default.fileExists(atPath: nested.path))
    }
}

@Suite("HistoryIndexFile")
struct HistoryIndexFileTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Save and load round trip")
    func roundTrip() throws {
        let directory = try TemporaryDirectory()
        let records = [record(daysAgo: 1, now: now), record(daysAgo: 2, now: now).withRecognizedText("hello")]
        try HistoryIndexFile.save(records, to: directory.url)
        #expect(HistoryIndexFile.load(from: directory.url) == records)
    }

    @Test("Missing index loads as empty")
    func missing() throws {
        let directory = try TemporaryDirectory()
        #expect(HistoryIndexFile.load(from: directory.url).isEmpty)
    }

    @Test("Optional fields may be absent in older files")
    func tolerantDecoding() throws {
        let directory = try TemporaryDirectory()
        let id = UUID()
        let json = """
        {"version":1,"records":[{"id":"\(id.uuidString)","createdAt":"2024-01-02T03:04:05Z",
        "fileName":"\(id.uuidString).png","thumbnailName":"\(id.uuidString).jpg",
        "pixelWidth":10,"pixelHeight":20,"scale":2,"kind":"gif"}]}
        """
        try Data(json.utf8).write(to: directory.url.appendingPathComponent(HistoryIndexFile.fileName))
        let loaded = HistoryIndexFile.load(from: directory.url)
        #expect(loaded.count == 1)
        #expect(loaded.first?.kind == .gif)
        #expect(loaded.first?.mode == nil)
        #expect(loaded.first?.sourceAppName == nil)
        let item = try #require(loaded.first?.item(root: directory.url))
        #expect(item.fileURL.lastPathComponent == "\(id.uuidString).png")
        #expect(item.pixelSize == CGSize(width: 10, height: 20))
    }

    @Test("Corrupt index is moved to index.json.bak")
    func corrupt() throws {
        let directory = try TemporaryDirectory()
        let index = directory.url.appendingPathComponent(HistoryIndexFile.fileName)
        let backup = directory.url.appendingPathComponent(HistoryIndexFile.backupName)
        try Data("old backup".utf8).write(to: backup)
        try Data("{ not json".utf8).write(to: index)

        #expect(HistoryIndexFile.load(from: directory.url).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: index.path))
        #expect(try Data(contentsOf: backup) == Data("{ not json".utf8))
    }

    @Test("Records own their original and thumbnail")
    func ownedFiles() {
        let value = record(daysAgo: 0, now: now)
        #expect(value.ownedFileNames == [value.fileName, value.thumbnailName])
    }
}
