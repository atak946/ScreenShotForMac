import CoreGraphics
import Foundation
import ShotCore

/// Writes temporary PNG files used for drag-and-drop export and prunes old ones.
public final class DragExporter: Sendable {
    public static let folderName = "ScreenShotForMac"
    private static let maxAge: TimeInterval = 24 * 60 * 60

    public let directory: URL

    public init(fileManager: FileManager = .default) {
        directory = fileManager.temporaryDirectory.appendingPathComponent(Self.folderName, isDirectory: true)
        Self.cleanUp(directory: directory, fileManager: fileManager)
    }

    /// Encodes the image as PNG into the temp folder and returns the file URL.
    public func writeTemporaryPNG(_ image: CGImage, scale: CGFloat, baseName: String) throws -> URL {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ExportError.folderUnavailable(path: directory.path)
        }
        let data = try ImageEncoder.pngData(for: image, scale: scale)
        let name = FilenameTemplate.sanitize(baseName)
        let url = SaveLocation.uniqueURL(in: directory, baseName: name, fileExtension: "png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(path: url.path, reason: error.localizedDescription)
        }
        return url
    }

    private static func cleanUp(directory: URL, fileManager: FileManager) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for url in contents {
            let modified = (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
            guard modified < cutoff else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                Log.export.error("Temp cleanup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
