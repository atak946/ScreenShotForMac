import Foundation
import ShotCore

/// Creates and resolves folder bookmarks for `WorkflowStep.saveToFolder`.
/// Tries security-scoped bookmarks first (sandboxed builds) and falls back to plain ones.
public enum FolderBookmark {
    public static func make(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            return data
        }
        do {
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            WorkflowLog.logger.error("Folder bookmark failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public static func resolve(_ data: Data) -> URL? {
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return url
        }
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
