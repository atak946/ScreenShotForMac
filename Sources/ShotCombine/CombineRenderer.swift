import CoreGraphics
import Foundation

/// Resolved geometry of a combined image, in output pixels with a top-left origin.
public struct CombinePlan: Sendable, Equatable {
    public let canvasSize: CGSize
    public let frames: [CGRect]
    public let outputScale: CGFloat
    public let cornerRadius: CGFloat
}

/// Pure, thread-safe renderer that stacks images vertically, horizontally or in a grid.
public enum CombineRenderer {
    /// Hard cap for either output side; larger layouts are scaled down uniformly.
    public static let maxPixelDimension: CGFloat = 16384

    /// Renders at full resolution. Output scale = the largest input scale.
    public static func render(images: [CombineImage], layout: CombineLayout) -> CGImage? {
        render(images: images, layout: layout, outputScale: nil)
    }

    /// Renders with an explicit output scale (pixels per point); `nil` uses the largest input scale.
    public static func render(images: [CombineImage], layout: CombineLayout, outputScale: CGFloat?) -> CGImage? {
        guard !images.isEmpty else { return nil }
        let plan = plan(sizes: images.map(\.pointSize), layout: layout, outputScale: outputScale ?? Self.outputScale(for: images))
        guard let context = makeContext(size: plan.canvasSize, colorSpace: colorSpace(for: images)) else { return nil }
        let sanitized = layout.sanitized()
        if sanitized.fillsBackground {
            context.setFillColor(sanitized.backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: plan.canvasSize))
        }
        context.interpolationQuality = .high
        for (image, frame) in zip(images, plan.frames) {
            draw(image.image, in: flipped(frame, canvasHeight: plan.canvasSize.height), radius: plan.cornerRadius, context: context)
        }
        return context.makeImage()
    }

    /// Largest backing scale among `images` (1 when empty).
    public static func outputScale(for images: [CombineImage]) -> CGFloat {
        images.map(\.scale).max() ?? 1
    }

    /// Computes canvas size and image frames for point `sizes` at `outputScale`.
    public static func plan(sizes: [CGSize], layout: CombineLayout, outputScale: CGFloat) -> CombinePlan {
        let layout = layout.sanitized()
        let fitted = matchedSizes(sizes, layout: layout)
        let (pointFrames, pointCanvas) = arrange(fitted, layout: layout)
        var scale = max(outputScale, 0.01)
        let longest = max(pointCanvas.width, pointCanvas.height) * scale
        if longest > maxPixelDimension {
            scale *= maxPixelDimension / longest
        }
        let canvas = CGSize(
            width: max(1, (pointCanvas.width * scale).rounded()),
            height: max(1, (pointCanvas.height * scale).rounded())
        )
        let frames = pointFrames.map { frame in
            CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
                .integral
        }
        return CombinePlan(canvasSize: canvas, frames: frames, outputScale: scale, cornerRadius: layout.cornerRadius * scale)
    }

    // MARK: Layout

    /// "Match sizes": same width for vertical / grid, same height for horizontal, upscale capped at 2x.
    static func matchedSizes(_ sizes: [CGSize], layout: CombineLayout) -> [CGSize] {
        guard layout.matchSizes, sizes.count > 1 else { return sizes }
        let byHeight = layout.arrangement == .horizontal
        let target = sizes.map { byHeight ? $0.height : $0.width }.max() ?? 0
        return sizes.map { size in
            let current = byHeight ? size.height : size.width
            guard current > 0 else { return size }
            let factor = min(target / current, CombineLayout.maxMatchUpscale)
            return CGSize(width: size.width * factor, height: size.height * factor)
        }
    }

    static func arrange(_ sizes: [CGSize], layout: CombineLayout) -> ([CGRect], CGSize) {
        switch layout.arrangement {
        case .vertical: return arrangeGrid(sizes, columns: 1, layout: layout)
        case .horizontal: return arrangeGrid(sizes, columns: max(sizes.count, 1), layout: layout)
        case .grid: return arrangeGrid(sizes, columns: layout.columns, layout: layout)
        }
    }

    /// Row-major grid; each column is as wide as its widest item, each row as tall as its tallest.
    private static func arrangeGrid(_ sizes: [CGSize], columns: Int, layout: CombineLayout) -> ([CGRect], CGSize) {
        let count = sizes.count
        guard count > 0 else { return ([], .zero) }
        let columnCount = min(max(columns, 1), count)
        let rowCount = Int((Double(count) / Double(columnCount)).rounded(.up))
        var columnWidths = [CGFloat](repeating: 0, count: columnCount)
        var rowHeights = [CGFloat](repeating: 0, count: rowCount)
        for (index, size) in sizes.enumerated() {
            columnWidths[index % columnCount] = max(columnWidths[index % columnCount], size.width)
            rowHeights[index / columnCount] = max(rowHeights[index / columnCount], size.height)
        }
        let spacing = CGFloat(layout.spacing)
        let padding = CGFloat(layout.padding)
        let columnOrigins = origins(of: columnWidths, start: padding, spacing: spacing)
        let rowOrigins = origins(of: rowHeights, start: padding, spacing: spacing)
        let frames = sizes.enumerated().map { index, size in
            let column = index % columnCount
            let row = index / columnCount
            let x = columnOrigins[column] + layout.alignment.offset(for: size.width, in: columnWidths[column])
            let y = rowOrigins[row] + layout.alignment.offset(for: size.height, in: rowHeights[row])
            return CGRect(x: x, y: y, width: size.width, height: size.height)
        }
        let canvas = CGSize(
            width: columnWidths.reduce(0, +) + spacing * CGFloat(columnCount - 1) + padding * 2,
            height: rowHeights.reduce(0, +) + spacing * CGFloat(rowCount - 1) + padding * 2
        )
        return (frames, canvas)
    }

    private static func origins(of lengths: [CGFloat], start: CGFloat, spacing: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        var cursor = start
        for length in lengths {
            result.append(cursor)
            cursor += length + spacing
        }
        return result
    }

    // MARK: Drawing

    private static func flipped(_ rect: CGRect, canvasHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func draw(_ image: CGImage, in rect: CGRect, radius: CGFloat, context: CGContext) {
        context.saveGState()
        let clampedRadius = min(radius, min(rect.width, rect.height) / 2)
        if clampedRadius > 0 {
            context.addPath(CGPath(roundedRect: rect, cornerWidth: clampedRadius, cornerHeight: clampedRadius, transform: nil))
            context.clip()
        }
        context.draw(image, in: rect)
        context.restoreGState()
    }

    private static func colorSpace(for images: [CombineImage]) -> CGColorSpace? {
        if let space = images.first?.image.colorSpace, space.model == .rgb, space.supportsOutput {
            return space
        }
        return CGColorSpace(name: CGColorSpace.sRGB)
    }

    private static func makeContext(size: CGSize, colorSpace: CGColorSpace?) -> CGContext? {
        guard let colorSpace else { return nil }
        return CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
