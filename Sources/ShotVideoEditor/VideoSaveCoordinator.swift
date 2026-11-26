import Foundation
import ShotCore

/// Exports the model's trim into a temporary file, then moves it to its final place
/// (a new "(edited)" copy next to the source, or over the source).
@MainActor
final class VideoSaveCoordinator {
    private var task: Task<URL, Error>?

    var isRunning: Bool { task != nil }

    /// Runs the export; progress lands in `model.phase`. Returns the saved file URL.
    func save(_ model: VideoEditorModel) async throws -> URL {
        model.pauseForExport()
        model.setPhase(.exporting(progress: 0))
        let temporary = try Self.temporaryURL(format: model.format)
        let request = model.makeExportRequest(outputURL: temporary)
        let format = model.format
        let progress: @Sendable (Double) -> Void = { [weak model] value in
            Task { @MainActor in
                guard let model, model.isExporting else { return }
                model.setPhase(.exporting(progress: min(max(value, 0), 1)))
            }
        }
        let task = Task.detached(priority: .userInitiated) { () throws -> URL in
            switch format {
            case .mp4: try await MP4Exporter.export(request, progress: progress)
            case .gif: try await GIFExporter.export(request, progress: progress)
            }
            return temporary
        }
        self.task = task
        defer { self.task = nil }
        do {
            let exported = try await task.value
            let saved = try place(exported, model: model)
            model.setPhase(.ready)
            return saved
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            model.setPhase(.ready)
            throw error
        }
    }

    func cancel() {
        task?.cancel()
    }

    private func place(_ exported: URL, model: VideoEditorModel) throws -> URL {
        let fileManager = FileManager.default
        if model.saveMode == .overwrite, model.canOverwrite {
            _ = try fileManager.replaceItemAt(model.sourceURL, withItemAt: exported)
            Log.videoEditor.info("Overwrote \(model.sourceURL.lastPathComponent, privacy: .public)")
            return model.sourceURL
        }
        let destination = Self.copyURL(for: model.sourceURL, format: model.format)
        try fileManager.moveItem(at: exported, to: destination)
        Log.videoEditor.info("Saved edited copy \(destination.lastPathComponent, privacy: .public)")
        return destination
    }

    private static func temporaryURL(format: VideoOutputFormat) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenShotForMac", isDirectory: true)
            .appendingPathComponent("VideoEdits", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(UUID().uuidString).\(format.fileExtension)")
    }

    /// `<name> (edited).<ext>`, then `<name> (edited 2).<ext>`, … in the source folder.
    private static func copyURL(for source: URL, format: VideoOutputFormat) -> URL {
        let folder = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        let suffix = String(localized: "edited", bundle: .module)
        var candidate = folder.appendingPathComponent("\(base) (\(suffix)).\(format.fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) (\(suffix) \(counter)).\(format.fileExtension)")
            counter += 1
        }
        return candidate
    }
}
