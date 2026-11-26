import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Pixelates rectangular regions of an image (used by the "Redact Sensitive Data" workflow step).
enum ImageRedactor {
    /// Block size relative to the region height, clamped so small text is still unreadable.
    private static let blockFraction: CGFloat = 0.45
    private static let minBlock: CGFloat = 8
    private static let maxBlock: CGFloat = 40
    /// Grows each region so glyph edges are covered.
    private static let padding: CGFloat = 3

    /// - Parameter regions: rects in image pixel coordinates, top-left origin.
    static func pixelate(_ image: CGImage, regions: [CGRect]) -> CGImage? {
        let source = CIImage(cgImage: image)
        let height = CGFloat(image.height)
        let bounds = source.extent
        let output = regions.reduce(source) { current, region in
            // Core Image uses a bottom-left origin.
            let flipped = CGRect(x: region.minX, y: height - region.maxY, width: region.width, height: region.height)
                .insetBy(dx: -padding, dy: -padding)
                .intersection(bounds)
            guard !flipped.isNull, !flipped.isEmpty else { return current }
            return pixelatedPatch(of: source, in: flipped).composited(over: current)
        }
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: bounds)
    }

    private static func pixelatedPatch(of source: CIImage, in rect: CGRect) -> CIImage {
        let block = min(max(rect.height * blockFraction, minBlock), maxBlock)
        let filter = CIFilter.pixellate()
        filter.inputImage = source.clampedToExtent().cropped(to: rect.insetBy(dx: -block, dy: -block))
        filter.scale = Float(block)
        filter.center = CGPoint(x: rect.minX, y: rect.minY)
        return (filter.outputImage ?? source).cropped(to: rect)
    }
}
