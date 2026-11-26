import CoreGraphics
import Foundation
import ShotCore

extension ExportService {
    /// Human-readable path of the current save folder (e.g. "~/Desktop"), for the Settings UI.
    public func saveFolderDisplayPath() -> String {
        let path = (try? SaveLocation(settings: settings).withFolder { $0.path }) ?? "~/Desktop"
        return (path as NSString).abbreviatingWithTildeInPath
    }

    /// Saves into `folder` (nil = configured save folder) using the filename template and format.
    /// The caller is responsible for security-scoped access to a custom `folder`.
    @discardableResult
    public func save(_ image: CGImage, scale: CGFloat, context: FilenameContext, to folder: URL?) throws -> URL {
        guard let folder else { return try save(image, scale: scale, context: context) }
        let format = settings.imageFormat
        let data = try encodeForExport(image, scale: scale, format: format)
        let url = SaveLocation.uniqueURL(in: folder, baseName: suggestedFilename(context: context), fileExtension: format.fileExtension)
        try writeExport(data, to: url)
        return url
    }

    /// Moves a file (e.g. a finished recording in the temp folder) into the configured save folder,
    /// keeping its name unique. Falls back to copy + delete across volumes. Returns the final URL.
    public func moveIntoSaveFolder(_ source: URL) throws -> URL {
        try SaveLocation(settings: settings).withFolder { folder in
            let base = source.deletingPathExtension().lastPathComponent
            let destination = SaveLocation.uniqueURL(in: folder, baseName: base, fileExtension: source.pathExtension)
            let fileManager = FileManager.default
            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                Log.export.error("Move failed, copying instead: \(error.localizedDescription, privacy: .public)")
                do {
                    try fileManager.copyItem(at: source, to: destination)
                    try? fileManager.removeItem(at: source)
                } catch {
                    throw ExportError.writeFailed(path: destination.path, reason: error.localizedDescription)
                }
            }
            Log.export.info("File moved to \(destination.path, privacy: .public)")
            return destination
        }
    }
}
