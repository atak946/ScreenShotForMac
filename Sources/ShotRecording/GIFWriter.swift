@preconcurrency import CoreMedia
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers
import VideoToolbox

/// Collects throttled frames and encodes an endlessly looping GIF when finished.
///
/// Frames are spooled to disk as PNG while recording so memory stays bounded; the
/// final GIF is encoded off the main actor in `finish`.
final class GIFWriter: SampleSink, @unchecked Sendable {
    private struct SpooledFrame {
        let url: URL
        let time: CMTime
    }

    /// GIF delays are stored in 1/100 s; browsers clamp anything shorter than 0.02 s.
    private static let minimumDelay: Double = 0.02

    private let url: URL
    private let spoolFolder: URL
    private let frameInterval: Double
    private var frames: [SpooledFrame] = []
    private var pixelSize = CGSize.zero

    init(url: URL, framesPerSecond: Int) throws {
        self.url = url
        frameInterval = 1 / Double(max(1, framesPerSecond))
        spoolFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenShotForMac", isDirectory: true)
            .appendingPathComponent("GIFFrames-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: spoolFolder, withIntermediateDirectories: true)
        } catch {
            throw CaptureError.captureFailed(String(
                localized: "Cannot create GIF frame folder: \(error.localizedDescription)",
                bundle: .module
            ))
        }
    }

    // MARK: - SampleSink

    func appendVideo(_ buffer: CMSampleBuffer) {
        let time = buffer.presentationTimeStamp
        if let last = frames.last, CMTimeSubtract(time, last.time).seconds < frameInterval * 0.9 { return }
        guard let pixelBuffer = buffer.imageBuffer else { return }
        var image: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard status == noErr, let image else {
            Log.recording.error("Cannot convert GIF frame (status \(status))")
            return
        }
        let frameURL = spoolFolder.appendingPathComponent(String(format: "frame-%06d.png", frames.count))
        guard Self.writePNG(image, to: frameURL) else {
            Log.recording.error("Cannot spool GIF frame \(self.frames.count)")
            return
        }
        pixelSize = CGSize(width: image.width, height: image.height)
        frames.append(SpooledFrame(url: frameURL, time: time))
    }

    func appendAudio(_ buffer: CMSampleBuffer, source: AudioSource) {
        // GIFs have no audio.
    }

    @concurrent
    func finish(endTime: CMTime) async throws -> TimeInterval {
        defer { removeSpool() }
        guard let first = frames.first, let last = frames.last else {
            throw CaptureError.captureFailed(String(localized: "No frames were recorded.", bundle: .module))
        }
        let delays = Self.delays(for: frames.map(\.time), endTime: endTime, fallback: frameInterval)
        try encode(delays: delays)
        let end = CMTimeCompare(endTime, last.time) > 0 ? endTime : last.time
        Log.recording.info("GIF written: \(self.frames.count) frames, \(Int(self.pixelSize.width))x\(Int(self.pixelSize.height))")
        return max(0, CMTimeSubtract(end, first.time).seconds)
    }

    func discard() {
        removeSpool()
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Log.recording.error("Cannot delete discarded GIF: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Encoding

    private func encode(delays: [Double]) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
        ) else {
            throw CaptureError.captureFailed(String(localized: "Cannot create GIF file.", bundle: .module))
        }
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        for (frame, delay) in zip(frames, delays) {
            guard let source = CGImageSourceCreateWithURL(frame.url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CaptureError.captureFailed(String(localized: "A spooled GIF frame could not be read.", bundle: .module))
            }
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay,
                ],
            ]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.captureFailed(String(localized: "GIF encoding failed.", bundle: .module))
        }
    }

    /// Per-frame display durations from capture timestamps; the last frame lasts until `endTime`.
    private static func delays(for times: [CMTime], endTime: CMTime, fallback: Double) -> [Double] {
        let nextTimes = times.dropFirst() + [endTime]
        return zip(times, nextTimes).map { current, next in
            let delta = CMTimeSubtract(next, current).seconds
            let value = delta.isFinite && delta > 0 ? delta : fallback
            return max(minimumDelay, (value * 100).rounded() / 100)
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func removeSpool() {
        guard FileManager.default.fileExists(atPath: spoolFolder.path) else { return }
        do {
            try FileManager.default.removeItem(at: spoolFolder)
        } catch {
            Log.recording.error("Cannot delete GIF frame folder: \(error.localizedDescription, privacy: .public)")
        }
    }
}
