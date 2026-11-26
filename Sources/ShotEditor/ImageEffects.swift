import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ShotCore

/// Lazily computes full-size blurred / pixelated versions of the base image.
/// Annotations clip these to their rect, so the effect is computed only once per editor.
@MainActor
final class ImageEffects {
    static let blurRadiusPoints: CGFloat = 10
    private static let pixelSizePoints: CGFloat = 10
    /// Rotations create new base images; keep a few so undo stays fast.
    private static let cacheLimit = 4

    private struct Entry {
        let image: CGImage
        var blur: CGImage?
        var pixelate: CGImage?
    }

    private let scale: CGFloat
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var entries: [Entry] = []

    init(scale: CGFloat) {
        self.scale = scale
    }

    func blurred(_ image: CGImage) -> CGImage? {
        let index = entryIndex(for: image)
        if let cached = entries[index].blur { return cached }
        let result = makeBlur(image)
        entries[index].blur = result
        return result
    }

    func pixelated(_ image: CGImage) -> CGImage? {
        let index = entryIndex(for: image)
        if let cached = entries[index].pixelate { return cached }
        let result = makePixelate(image)
        entries[index].pixelate = result
        return result
    }

    private func entryIndex(for image: CGImage) -> Int {
        if let index = entries.firstIndex(where: { $0.image === image }) { return index }
        if entries.count >= Self.cacheLimit { entries.removeFirst() }
        entries.append(Entry(image: image))
        return entries.count - 1
    }

    /// Uncached blur of any image (used for layered effect regions).
    func makeBlur(_ baseImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: baseImage)
        let output = input
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Double(Self.blurRadiusPoints * scale))
            .cropped(to: input.extent)
        return render(output, source: baseImage, label: "blur")
    }

    /// Uncached pixelate; `gridOrigin` (Core Image pixel coordinates) aligns the cells
    /// with the full-image grid so region renders match.
    func makePixelate(_ baseImage: CGImage, gridOrigin: CGPoint = .zero) -> CGImage? {
        let input = CIImage(cgImage: baseImage)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(max(Self.pixelSizePoints * scale, 2))
        filter.center = gridOrigin
        guard let output = filter.outputImage?.cropped(to: input.extent) else {
            Log.editor.error("Pixellate filter produced no output")
            return nil
        }
        return render(output, source: baseImage, label: "pixelate")
    }

    private func render(_ image: CIImage, source: CGImage, label: String) -> CGImage? {
        let extent = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let result: CGImage? = if let colorSpace = source.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) {
            context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: colorSpace)
        } else {
            context.createCGImage(image, from: extent)
        }
        if result == nil {
            Log.editor.error("Failed to render \(label, privacy: .public) effect")
        }
        return result
    }
}
