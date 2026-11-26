@preconcurrency import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import ShotCore

/// Owns the SCStream and forwards valid, retimed samples to a `SampleSink`.
///
/// Sample callbacks arrive on a private serial queue. `start` / `stop` / `pause` /
/// `resume` are called sequentially by the recording session, so the mutable
/// `stream` reference is never accessed concurrently.
final class StreamCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.screenshotformac.recording.samples", qos: .userInteractive)
    private let sink: SampleSink
    private let retimer = SampleRetimer()
    private let onFailure: @Sendable (Error) -> Void
    private var stream: SCStream?

    init(sink: SampleSink, onFailure: @escaping @Sendable (Error) -> Void) {
        self.sink = sink
        self.onFailure = onFailure
    }

    func start(plan: CapturePlan) async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw Self.mapError(error)
        }
        let filter = try CaptureFilterFactory.filter(for: plan, content: content)
        let config = CaptureFilterFactory.configuration(for: plan)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            if plan.capturesSystemAudio {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            }
            if plan.capturesMicrophone, #available(macOS 15.0, *) {
                try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
            }
            try await stream.startCapture()
        } catch {
            throw Self.mapError(error)
        }
        self.stream = stream
        Log.recording.info("Stream started at \(plan.outputWidth)x\(plan.outputHeight) @\(plan.framesPerSecond) fps")
    }

    /// Stops the stream and waits until every queued sample was delivered.
    /// Returns the stop time on the output timeline.
    func stop() async -> CMTime {
        let endTime = retimer.adjustedNow()
        if let stream {
            self.stream = nil
            do {
                try await stream.stopCapture()
            } catch {
                // Already stopped (e.g. after a stream error); nothing else to do.
                Log.recording.info("stopCapture reported: \(error.localizedDescription, privacy: .public)")
            }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
        return endTime
    }

    func pause() { retimer.pause() }
    func resume() { retimer.resume() }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch type {
        case .screen:
            guard Self.isCompleteFrame(sampleBuffer), let retimed = retimer.retime(sampleBuffer) else { return }
            sink.appendVideo(retimed)
        case .audio:
            guard let retimed = retimer.retime(sampleBuffer) else { return }
            sink.appendAudio(retimed, source: .system)
        default:
            guard #available(macOS 15.0, *), type == .microphone,
                  let retimed = retimer.retime(sampleBuffer) else { return }
            sink.appendAudio(retimed, source: .microphone)
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Log.recording.error("Stream stopped with error: \(error.localizedDescription, privacy: .public)")
        onFailure(error)
    }

    // MARK: - Helpers

    private static func isCompleteFrame(_ buffer: CMSampleBuffer) -> Bool {
        guard buffer.imageBuffer != nil,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
              as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else { return false }
        return status == .complete
    }

    static func mapError(_ error: Error) -> Error {
        if error is CaptureError { return error }
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.Code.userDeclined.rawValue {
            return CaptureError.permissionDenied
        }
        return CaptureError.captureFailed(error.localizedDescription)
    }

    static func isUserStopped(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SCStreamErrorDomain && nsError.code == SCStreamError.Code.userStopped.rawValue
    }
}
