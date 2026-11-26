import Foundation
import ShotCore

/// Pure retention and safety rules for the history folder.
enum HistoryRetention {
    static let checkInterval: Duration = .seconds(24 * 60 * 60)
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    /// Records older than `retentionDays`; empty when `retentionDays <= 0` (keep forever).
    static func expired(_ records: [HistoryRecord], retentionDays: Int, now: Date = Date()) -> [HistoryRecord] {
        guard retentionDays > 0 else { return [] }
        let cutoff = now.addingTimeInterval(-TimeInterval(retentionDays) * secondsPerDay)
        return records.filter { $0.createdAt < cutoff }
    }

    /// Files in the root that look like history items (UUID-prefixed) but are not referenced
    /// by any record, e.g. left behind by a crash during a write.
    static func orphanFiles(in root: URL, referenced: Set<String>) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter { url in
            let name = url.lastPathComponent
            guard !referenced.contains(name), let prefix = name.split(separator: ".").first else { return false }
            return UUID(uuidString: String(prefix)) != nil
        }
    }

    /// Deletes a file only if it lives directly inside the history root.
    static func deleteFile(_ url: URL, root: URL) throws {
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        guard file.deletingLastPathComponent().path == base.path else {
            throw HistoryError.outsideHistoryDirectory(file.path)
        }
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
    }
}
