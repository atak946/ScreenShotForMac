@preconcurrency import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Renders the trimmed range into an animated GIF (frames from `AVAssetImageGenerator`, written with ImageIO).
enum GIFExporter {
    private static let timescale: CMTimeScale = 600
    /// Browsers clamp shorter GIF delays.
    private static let minimumDelay = 0.02

    static func export(_ request: VideoExportRequest, progress: @escaping @Sendable (Double) -> Void) async throws {
        let fps = Double(max(1, request.gifFramesPerSecond))
        let outputDuration = max(0, request.end - request.start) / request.speed
        let frameCount = max(1, Int((outputDuration * fps).rounded()))
        let delay = max(minimumDelay, 1 / fps)

        let generator = makeGenerator(for: request, fps: fps)
        try? FileManager.default.removeItem(at: request.outputURL)
        guard let destination = CGImageDestinationCreateWithURL(
            request.outputURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { throw VideoEditorError.gifCreationFailed }

        let fileProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)
        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delay,
            kCGImagePropertyGIFUnclampedDelayTime: delay,
        ]] as CFDictionary

        for index in 0..<frameCount {
            try Task.checkCancellation()
            let sourceSeconds = request.start + Double(index) / fps * request.speed
            let time = CMTime(seconds: min(sourceSeconds, request.end), preferredTimescale: timescale)
            let image = try await generator.image(at: time).image
            CGImageDestinationAddImage(destination, image, frameProperties)
            progress(Double(index + 1) / Double(frameCount))
        }
        guard CGImageDestinationFinalize(destination) else { throw VideoEditorError.gifCreationFailed }
    }

    private static func makeGenerator(for request: VideoExportRequest, fps: Double) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: request.sourceURL))
        generator.appliesPreferredTrackTransform = true
        if let maxWidth = request.gifMaxWidth {
            generator.maximumSize = CGSize(width: maxWidth, height: 0)
        }
        let tolerance = CMTime(seconds: 0.5 / fps, preferredTimescale: timescale)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return generator
    }
}
