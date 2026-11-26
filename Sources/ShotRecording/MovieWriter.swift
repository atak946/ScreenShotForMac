@preconcurrency import AVFoundation
import Foundation
import ShotCore

/// Writes screen frames (H.264, or HEVC for very large sizes) and AAC audio tracks to an MP4.
/// `append*` runs on the capture queue; `finish` / `discard` after the queue drained.
final class MovieWriter: SampleSink, @unchecked Sendable {
    /// Largest frame the H.264 encoder handles; bigger captures switch to HEVC.
    private static let maxH264Width = 4096
    private static let maxH264Height = 2304

    private let url: URL
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInputs: [AudioSource: AVAssetWriterInput]
    private var firstVideoTime: CMTime = .invalid
    private var lastVideoTime: CMTime = .invalid
    private var lastAudioTimes: [AudioSource: CMTime] = [:]
    private var didLogFailure = false

    init(url: URL, width: Int, height: Int, framesPerSecond: Int, audioSources: Set<AudioSource>) throws {
        self.url = url
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw CaptureError.captureFailed(String(localized: "Cannot create movie file: \(error.localizedDescription)", bundle: .module))
        }
        writer.shouldOptimizeForNetworkUse = true

        let useHEVC = width > Self.maxH264Width || height > Self.maxH264Height
        let settings = Self.videoSettings(width: width, height: height, fps: framesPerSecond, hevc: useHEVC)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw CaptureError.captureFailed(String(localized: "The movie writer rejected the video settings.", bundle: .module))
        }
        writer.add(videoInput)

        var inputs: [AudioSource: AVAssetWriterInput] = [:]
        for source in audioSources {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.audioSettings)
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                inputs[source] = input
            } else {
                Log.recording.error("Cannot add audio track for \(String(describing: source), privacy: .public)")
            }
        }
        audioInputs = inputs
        Log.recording.info("Movie writer ready: \(width)x\(height), codec \(useHEVC ? "HEVC" : "H.264", privacy: .public)")
    }

    // MARK: - SampleSink

    func appendVideo(_ buffer: CMSampleBuffer) {
        let time = buffer.presentationTimeStamp
        if !firstVideoTime.isValid {
            guard writer.startWriting() else {
                logFailureOnce("startWriting failed")
                return
            }
            writer.startSession(atSourceTime: time)
            firstVideoTime = time
        }
        guard writer.status == .writing else { return logFailureOnce("writer not writing") }
        guard !lastVideoTime.isValid || CMTimeCompare(time, lastVideoTime) > 0, videoInput.isReadyForMoreMediaData else { return }
        if videoInput.append(buffer) {
            lastVideoTime = time
        } else {
            logFailureOnce("video append failed")
        }
    }

    func appendAudio(_ buffer: CMSampleBuffer, source: AudioSource) {
        guard firstVideoTime.isValid, writer.status == .writing, let input = audioInputs[source] else { return }
        let time = buffer.presentationTimeStamp
        guard CMTimeCompare(time, firstVideoTime) >= 0 else { return }
        if let last = lastAudioTimes[source], CMTimeCompare(time, last) <= 0 { return }
        guard input.isReadyForMoreMediaData else { return }
        if input.append(buffer) {
            lastAudioTimes[source] = time
        } else {
            logFailureOnce("audio append failed")
        }
    }

    @concurrent
    func finish(endTime: CMTime) async throws -> TimeInterval {
        guard firstVideoTime.isValid, lastVideoTime.isValid else {
            discard()
            throw CaptureError.captureFailed(String(localized: "No video frames were recorded.", bundle: .module))
        }
        guard writer.status == .writing else {
            let reason = writer.error?.localizedDescription ?? String(localized: "unknown error", bundle: .module)
            discard()
            throw CaptureError.captureFailed(String(localized: "Movie writing failed: \(reason)", bundle: .module))
        }
        let end = CMTimeCompare(endTime, lastVideoTime) > 0 ? endTime : lastVideoTime
        videoInput.markAsFinished()
        audioInputs.values.forEach { $0.markAsFinished() }
        writer.endSession(atSourceTime: end)
        await writer.finishWriting()
        guard writer.status == .completed else {
            let reason = writer.error?.localizedDescription ?? String(localized: "unknown error", bundle: .module)
            try? FileManager.default.removeItem(at: url)
            throw CaptureError.captureFailed(String(localized: "Movie writing failed: \(reason)", bundle: .module))
        }
        return max(0, CMTimeSubtract(end, firstVideoTime).seconds)
    }

    func discard() {
        if writer.status == .writing {
            writer.cancelWriting()
        }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Log.recording.error("Cannot delete discarded movie: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Settings

    private func logFailureOnce(_ message: String) {
        guard !didLogFailure else { return }
        didLogFailure = true
        let reason = writer.error?.localizedDescription ?? "n/a"
        Log.recording.error("Movie writer: \(message, privacy: .public) (\(reason, privacy: .public))")
    }

    private static var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
    }

    private static func videoSettings(width: Int, height: Int, fps: Int, hevc: Bool) -> [String: Any] {
        let bitsPerPixel = hevc ? 0.05 : 0.08
        let rawBitrate = Double(width * height * max(1, fps)) * bitsPerPixel
        let bitrate = min(max(rawBitrate, 2_000_000), 60_000_000)
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: Int(bitrate),
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: max(1, fps * 2),
            AVVideoAllowFrameReorderingKey: false,
        ]
        if !hevc {
            compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }
        return [
            AVVideoCodecKey: hevc ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: compression,
        ]
    }
}
