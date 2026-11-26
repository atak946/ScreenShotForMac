@preconcurrency import AVFoundation
import ShotCore

/// Evenly spaced filmstrip thumbnails for the timeline.
enum ThumbnailLoader {
    private static let timescale: CMTimeScale = 600

    static func load(url: URL, duration: Double, count: Int, height: CGFloat) async -> [CGImage] {
        guard duration > 0, count > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 0, height: height)
        let tolerance = CMTime(seconds: duration / Double(count) / 2, preferredTimescale: timescale)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var images: [CGImage] = []
        for index in 0..<count {
            guard !Task.isCancelled else { break }
            let seconds = duration * (Double(index) + 0.5) / Double(count)
            do {
                let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: timescale)).image
                images.append(image)
            } catch {
                // A missing frame leaves a gap; keep the rest of the strip.
                Log.videoEditor
                    .debug(
                        "Thumbnail at \(seconds, format: .fixed(precision: 2)) s failed: \(error.localizedDescription, privacy: .public)"
                    )
            }
        }
        return images
    }
}
