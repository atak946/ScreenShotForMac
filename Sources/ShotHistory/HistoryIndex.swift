import CoreGraphics
import Foundation
import ShotCore

/// Codable on-disk representation of one history entry. File names are stored
/// relative to the history root so the folder can be moved without breaking links.
struct HistoryRecord: Codable, Sendable, Equatable {
    let id: UUID
    let createdAt: Date
    let fileName: String
    let thumbnailName: String
    let pixelWidth: Double
    let pixelHeight: Double
    let scale: Double
    let sourceAppName: String?
    let kind: HistoryItem.Kind
    let mode: CaptureMode?
    let screenRect: CGRect?
    let recognizedText: String?

    func item(root: URL) -> HistoryItem {
        HistoryItem(
            id: id,
            createdAt: createdAt,
            fileURL: root.appendingPathComponent(fileName, isDirectory: false),
            thumbnailURL: root.appendingPathComponent(thumbnailName, isDirectory: false),
            pixelSize: CGSize(width: pixelWidth, height: pixelHeight),
            scale: CGFloat(scale),
            sourceAppName: sourceAppName,
            kind: kind,
            recognizedText: recognizedText
        )
    }

    func withRecognizedText(_ text: String) -> HistoryRecord {
        HistoryRecord(
            id: id, createdAt: createdAt, fileName: fileName, thumbnailName: thumbnailName,
            pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale,
            sourceAppName: sourceAppName, kind: kind, mode: mode, screenRect: screenRect,
            recognizedText: text
        )
    }

    /// All file names owned by this record (original + thumbnail).
    var ownedFileNames: [String] { [fileName, thumbnailName] }
}

/// Versioned wrapper so the format can evolve.
private struct HistoryIndexDocument: Codable {
    let version: Int
    let records: [HistoryRecord]
}

/// Reads and writes `index.json`. Corrupt files are backed up to `index.json.bak`.
enum HistoryIndexFile {
    static let fileName = "index.json"
    static let backupName = "index.json.bak"
    private static let currentVersion = 1

    static func load(from root: URL) -> [HistoryRecord] {
        let url = root.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(HistoryIndexDocument.self, from: data).records
        } catch {
            Log.export.error("History index is corrupt, starting fresh: \(error.localizedDescription, privacy: .public)")
            backUpCorruptIndex(url, root: root)
            return []
        }
    }

    static func save(_ records: [HistoryRecord], to root: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(HistoryIndexDocument(version: currentVersion, records: records))
        try data.write(to: root.appendingPathComponent(fileName, isDirectory: false), options: .atomic)
    }

    private static func backUpCorruptIndex(_ url: URL, root: URL) {
        let backup = root.appendingPathComponent(backupName, isDirectory: false)
        let manager = FileManager.default
        do {
            if manager.fileExists(atPath: backup.path) {
                try manager.removeItem(at: backup)
            }
            try manager.moveItem(at: url, to: backup)
        } catch {
            Log.export.error("Could not back up corrupt history index: \(error.localizedDescription, privacy: .public)")
        }
    }
}
