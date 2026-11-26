@preconcurrency import AVFoundation
import ShotCore

/// Trims (and optionally mutes / retimes) a movie into an MP4 via `AVAssetExportSession`.
enum MP4Exporter {
    private static let timescale: CMTimeScale = 600
    private static let pollInterval: Duration = .milliseconds(100)

    static func export(_ request: VideoExportRequest, progress: @escaping @Sendable (Double) -> Void) async throws {
        let composition = try await makeComposition(for: request)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoEditorError.exportUnavailable
        }
        session.shouldOptimizeForNetworkUse = true
        session.audioTimePitchAlgorithm = .spectral
        try? FileManager.default.removeItem(at: request.outputURL)
        if #available(macOS 15.0, *) {
            try await exportModern(session, to: request.outputURL, progress: progress)
        } else {
            try await exportLegacy(session, to: request.outputURL, progress: progress)
        }
    }

    private static func makeComposition(for request: VideoExportRequest) async throws -> AVComposition {
        let asset = AVURLAsset(url: request.sourceURL)
        let range = CMTimeRange(
            start: CMTime(seconds: request.start, preferredTimescale: timescale),
            end: CMTime(seconds: request.end, preferredTimescale: timescale)
        )
        let composition = AVMutableComposition()
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let video = videoTracks.first else { throw VideoEditorError.unreadable }
        try await insert(video, range: range, into: composition)
        if !request.removesAudio {
            for audio in try await asset.loadTracks(withMediaType: .audio) {
                try await insert(audio, range: range, into: composition)
            }
        }
        if request.speed != 1 {
            let full = CMTimeRange(start: .zero, duration: range.duration)
            composition.scaleTimeRange(full, toDuration: CMTimeMultiplyByFloat64(range.duration, multiplier: 1 / request.speed))
        }
        return composition
    }

    private static func insert(_ track: AVAssetTrack, range: CMTimeRange, into composition: AVMutableComposition) async throws {
        guard let target = composition.addMutableTrack(
            withMediaType: track.mediaType,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw VideoEditorError.exportUnavailable }
        try target.insertTimeRange(range, of: track, at: .zero)
        target.preferredTransform = try await track.load(.preferredTransform)
    }

    @available(macOS 15.0, *)
    private static func exportModern(
        _ session: AVAssetExportSession,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let box = ExportSessionBox(session)
        let monitor = Task {
            for await state in box.session.states(updateInterval: 0.1) {
                if case let .exporting(report) = state { progress(report.fractionCompleted) }
            }
        }
        defer { monitor.cancel() }
        try await session.export(to: url, as: .mp4)
        progress(1)
    }

    private static func exportLegacy(
        _ session: AVAssetExportSession,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        session.outputURL = url
        session.outputFileType = .mp4
        let box = ExportSessionBox(session)
        let poller = Task {
            while !Task.isCancelled {
                progress(Double(box.session.progress))
                try? await Task.sleep(for: pollInterval)
            }
        }
        defer { poller.cancel() }
        await withTaskCancellationHandler {
            await session.export()
        } onCancel: {
            box.session.cancelExport()
        }
        try Task.checkCancellation()
        guard session.status == .completed else {
            let reason = session.error?.localizedDescription ?? String(localized: "Unknown error", bundle: .module)
            throw VideoEditorError.exportFailed(reason)
        }
        progress(1)
    }
}

/// `AVAssetExportSession` is thread-safe for progress / state reads and cancellation,
/// but is not annotated `Sendable`; this box lets monitoring tasks reference it.
private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
