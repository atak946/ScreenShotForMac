import AppKit
import Foundation
import ShotCore

/// Resolves the configured save folder and builds unique destination URLs.
@MainActor
struct SaveLocation {
    let settings: AppSettings

    /// Runs `body` with access to the save folder (security-scoped when configured).
    func withFolder<T>(_ body: (URL) throws -> T) throws -> T {
        guard let bookmark = settings.saveFolderBookmark else {
            return try body(Self.defaultFolder())
        }
        let folder = try resolve(bookmark)
        let didStart = folder.startAccessingSecurityScopedResource()
        defer { if didStart { folder.stopAccessingSecurityScopedResource() } }
        try Self.ensureDirectory(folder)
        return try body(folder)
    }

    /// Stores a security-scoped bookmark for the folder.
    func store(folder: URL) throws {
        do {
            settings.saveFolderBookmark = try folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ExportError.bookmarkResolutionFailed(reason: error.localizedDescription)
        }
    }

    static func defaultFolder() throws -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        try ensureDirectory(desktop)
        return desktop
    }

    /// Appends " (2)", " (3)"… until the name is free.
    nonisolated static func uniqueURL(in folder: URL, baseName: String, fileExtension: String) -> URL {
        let fileManager = FileManager.default
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var index = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) (\(index))").appendingPathExtension(fileExtension)
            index += 1
        }
        return candidate
    }

    private func resolve(_ bookmark: Data) throws -> URL {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            Log.export.error("Bookmark resolution failed: \(error.localizedDescription, privacy: .public)")
            throw ExportError.bookmarkResolutionFailed(reason: error.localizedDescription)
        }
        if isStale { refresh(url) }
        return url
    }

    private func refresh(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            try store(folder: url)
            Log.export.info("Refreshed stale save folder bookmark")
        } catch {
            Log.export.error("Could not refresh stale bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func ensureDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw ExportError.folderUnavailable(path: url.path) }
            return
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw ExportError.folderUnavailable(path: url.path)
        }
    }
}
