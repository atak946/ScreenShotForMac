import CoreGraphics
import Foundation

/// Pure helpers that cut one image into slices along cut fractions (0…1, top-left origin).
public enum SplitRenderer {
    public static let countRange: ClosedRange<Int> = 2...20
    /// Cuts closer than this fraction to an edge or to each other are dropped.
    static let minimumGap = 0.005

    /// Fractions for `count` equal slices (`count - 1` cuts).
    public static func equalCuts(count: Int) -> [Double] {
        let count = count.clamped(to: countRange)
        return (1..<count).map { Double($0) / Double(count) }
    }

    /// Sorted, de-duplicated cuts strictly inside (0, 1).
    public static func normalizedCuts(_ cuts: [Double]) -> [Double] {
        var result: [Double] = []
        for cut in cuts.sorted() where cut > minimumGap && cut < 1 - minimumGap {
            if let last = result.last, cut - last < minimumGap { continue }
            result.append(cut)
        }
        return result
    }

    /// Pixel rects (top-left origin) of every slice.
    public static func sliceRects(pixelSize: CGSize, axis: SplitAxis, cuts: [Double]) -> [CGRect] {
        let length = axis == .horizontal ? pixelSize.height : pixelSize.width
        let edges = [0] + normalizedCuts(cuts).map { ($0 * length).rounded() } + [length]
        return zip(edges, edges.dropFirst()).compactMap { start, end in
            guard end - start >= 1 else { return nil }
            switch axis {
            case .horizontal: return CGRect(x: 0, y: start, width: pixelSize.width, height: end - start)
            case .vertical: return CGRect(x: start, y: 0, width: end - start, height: pixelSize.height)
            }
        }
    }

    /// Crops `image` into slices; order is top-to-bottom or left-to-right.
    public static func slices(of image: CGImage, axis: SplitAxis, cuts: [Double]) -> [CGImage] {
        let size = CGSize(width: image.width, height: image.height)
        return sliceRects(pixelSize: size, axis: axis, cuts: cuts).compactMap { image.cropping(to: $0) }
    }
}
