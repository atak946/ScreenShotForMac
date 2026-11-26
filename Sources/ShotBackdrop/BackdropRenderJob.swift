import CoreGraphics
import Foundation

/// Sendable box so a `CGImage` can cross into and out of background render tasks.
/// `CGImage` is immutable, so sharing it between threads is safe.
struct ImageBox: @unchecked Sendable {
    let image: CGImage
}

/// Everything needed to render one backdrop frame off the main actor.
struct BackdropRenderJob: Sendable {
    let source: ImageBox
    let scale: CGFloat
    let style: BackdropStyle
    let wallpaper: ImageBox?
    let fixedSizeFactor: CGFloat

    func render() -> CGImage? {
        BackdropRenderer.render(
            image: source.image,
            scale: scale,
            style: style,
            wallpaper: wallpaper?.image,
            fixedSizeFactor: fixedSizeFactor
        )
    }

    /// Renders on a background thread.
    func renderDetached(priority: TaskPriority = .userInitiated) async -> CGImage? {
        let job = self
        let box = await Task.detached(priority: priority) { job.render().map(ImageBox.init) }.value
        return box?.image
    }
}

/// Downscaled copy of the capture used for fast previews / thumbnails.
struct ScaledSource {
    let image: CGImage
    /// Output pixels per source pixel (≤ 1).
    let factor: CGFloat

    init(_ image: CGImage, maxPixels: CGFloat) {
        let longest = CGFloat(max(image.width, image.height))
        let factor = min(1, maxPixels / max(longest, 1))
        self.factor = factor
        self.image = Self.downscale(image, factor: factor) ?? image
    }

    private static func downscale(_ image: CGImage, factor: CGFloat) -> CGImage? {
        guard factor < 1 else { return image }
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
