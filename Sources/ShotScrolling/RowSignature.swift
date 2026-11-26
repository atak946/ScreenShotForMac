import CoreGraphics

/// Grayscale per-row fingerprints of one frame.
///
/// Each pixel row is reduced to `bucketCount` luminance averages (0...255). Rows keep their
/// full vertical resolution so offsets stay pixel-accurate; only the horizontal axis is reduced.
struct RowSignatures: Sendable {
    static let bucketCount = 32
    private static let pixelsPerBucket = 8
    /// Rightmost columns are ignored so overlay scroll bars do not disturb matching.
    private static let maxIgnoredColumns = 40

    let rowCount: Int
    /// `rowCount * bucketCount` bucket means, row-major.
    let buckets: [UInt8]
    /// Sum of each row's buckets, used by the coarse search.
    let rowSums: [Int32]

    /// Builds signatures for `image`. Returns nil when the image cannot be rendered.
    static func make(from image: CGImage) -> RowSignatures? {
        let height = image.height
        guard height > 0, image.width > 1 else { return nil }
        let ignored = min(image.width / 8, maxIgnoredColumns)
        let cropRect = CGRect(x: 0, y: 0, width: image.width - ignored, height: height)
        let source = image.cropping(to: cropRect) ?? image
        guard let gray = renderGray(source, height: height) else { return nil }
        return reduce(gray, height: height)
    }

    /// Sum of absolute bucket differences between `row` here and `otherRow` in `other`.
    func difference(row: Int, to other: RowSignatures, row otherRow: Int) -> Int {
        let count = Self.bucketCount
        var total = 0
        buckets.withUnsafeBufferPointer { lhs in
            other.buckets.withUnsafeBufferPointer { rhs in
                let a = row * count
                let b = otherRow * count
                for index in 0..<count {
                    total += abs(Int(lhs[a + index]) - Int(rhs[b + index]))
                }
            }
        }
        return total
    }

    // MARK: - Private

    private struct GrayBitmap {
        let pixels: [UInt8]
        let bytesPerRow: Int
    }

    private static func renderGray(_ image: CGImage, height: Int) -> GrayBitmap? {
        let columns = bucketCount * pixelsPerBucket
        guard let context = CGContext(
            data: nil,
            width: columns,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: height))
        guard let data = context.data else { return nil }
        let length = context.bytesPerRow * height
        let buffer = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: length)
        return GrayBitmap(pixels: Array(buffer), bytesPerRow: context.bytesPerRow)
    }

    /// Averages each row into buckets. Bitmap memory row 0 is the top of the image.
    private static func reduce(_ bitmap: GrayBitmap, height: Int) -> RowSignatures {
        var buckets = [UInt8](repeating: 0, count: height * bucketCount)
        var sums = [Int32](repeating: 0, count: height)
        bitmap.pixels.withUnsafeBufferPointer { pixels in
            for row in 0..<height {
                let rowStart = row * bitmap.bytesPerRow
                var rowSum: Int32 = 0
                for bucket in 0..<bucketCount {
                    let start = rowStart + bucket * pixelsPerBucket
                    var sum = 0
                    for offset in 0..<pixelsPerBucket { sum += Int(pixels[start + offset]) }
                    let mean = UInt8(sum / pixelsPerBucket)
                    buckets[row * bucketCount + bucket] = mean
                    rowSum += Int32(mean)
                }
                sums[row] = rowSum
            }
        }
        return RowSignatures(rowCount: height, buckets: buckets, rowSums: sums)
    }
}
