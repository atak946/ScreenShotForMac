import CoreGraphics
import ShotCore

/// Result of feeding one frame to the stitcher.
struct StitchUpdate: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        /// First frame, the stitch has started.
        case started
        /// New content appended (rows).
        case appended(Int)
        /// Nothing moved.
        case unchanged
        /// The user scrolled up; frame ignored.
        case scrolledUp
        /// No reliable overlap with the previous frame.
        case noMatch
        /// Height cap reached; further frames are ignored.
        case capReached
    }

    let status: Status
    /// Stitched result size in pixels.
    let pixelWidth: Int
    let pixelHeight: Int
    /// Height of a single frame in pixels.
    let frameHeight: Int
}

/// Accumulates scrolled frames into one tall image. All pixel work happens on this actor.
///
/// Layout of the result: rows `[0, H - footer)` of the first frame, then each appended strip
/// (the rows revealed just above the sticky footer), then the footer of the last accepted frame.
actor ImageStitcher {
    static let maxPixelHeight = 30000

    private var first: CGImage?
    private var last: StitchFrame?
    private var strips: [CGImage] = []
    private var bands: StaticBands?
    private var height = 0
    private var isCapped = false

    func add(_ frame: SendableImage) -> StitchUpdate {
        let image = frame.cgImage
        guard let signatures = RowSignatures.make(from: image) else { return update(.noMatch) }
        let current = StitchFrame(image: image, signatures: signatures)
        guard let previous = last else {
            first = image
            last = current
            height = image.height
            return update(.started)
        }
        guard !isCapped else { return update(.capReached) }
        guard image.width == previous.image.width, image.height == previous.image.height else {
            Log.capture.error("Scrolling frame size changed; frame ignored")
            return update(.noMatch)
        }
        return integrate(current, after: previous)
    }

    /// Composes the final image, or nil when nothing was captured.
    func compose() -> SendableImage? {
        guard let first else { return nil }
        guard let last, !strips.isEmpty else { return SendableImage(cgImage: first) }
        let footer = bands?.footer ?? 0
        let frameHeight = first.height
        let pieces = [ImageOps.copyRows(of: first, rows: 0..<(frameHeight - footer))]
            + strips.map(Optional.some)
            + [footer > 0 ? ImageOps.copyRows(of: last.image, rows: (frameHeight - footer)..<frameHeight) : nil]
        let resolved = pieces.compactMap(\.self)
        guard let image = ImageOps.stack(resolved, width: first.width, colorSpace: first.colorSpace) else {
            Log.capture.error("Failed to compose the scrolling capture")
            return nil
        }
        return SendableImage(cgImage: image)
    }

    // MARK: - Private

    private func integrate(_ current: StitchFrame, after previous: StitchFrame) -> StitchUpdate {
        guard let detected = OffsetEstimator.staticBands(previous: previous.signatures, current: current.signatures) else {
            return update(.unchanged)
        }
        let activeBands = bands ?? detected
        switch OffsetEstimator.estimate(previous: previous, current: current, bands: activeBands) {
        case .unchanged:
            return update(.unchanged)
        case .noMatch:
            return update(.noMatch)
        case let .shift(shift) where shift < 0:
            return update(.scrolledUp)
        case let .shift(shift):
            return append(current, shift: shift, bands: activeBands)
        }
    }

    private func append(_ current: StitchFrame, shift: Int, bands activeBands: StaticBands) -> StitchUpdate {
        var rows = shift
        if height + rows >= Self.maxPixelHeight {
            rows = Self.maxPixelHeight - height
            isCapped = true
            Log.capture.warning("Scrolling capture reached the \(Self.maxPixelHeight) px height cap")
        }
        guard rows > 0 else { return update(.capReached) }
        let frameHeight = current.image.height
        let bottom = frameHeight - activeBands.footer
        let stripRows = (bottom - shift)..<(bottom - shift + rows)
        guard let strip = ImageOps.copyRows(of: current.image, rows: stripRows) else {
            Log.capture.error("Failed to copy a scrolling strip")
            return update(.noMatch)
        }
        strips.append(strip)
        height += rows
        bands = activeBands
        last = current
        return update(isCapped ? .capReached : .appended(rows))
    }

    private func update(_ status: StitchUpdate.Status) -> StitchUpdate {
        StitchUpdate(
            status: status,
            pixelWidth: first?.width ?? 0,
            pixelHeight: height,
            frameHeight: first?.height ?? 0
        )
    }
}

/// Pixel-exact image helpers.
enum ImageOps {
    private static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    /// Copies `rows` (top-left origin) into a standalone image so the source frame can be released.
    static func copyRows(of image: CGImage, rows: Range<Int>) -> CGImage? {
        guard !rows.isEmpty,
              let cropped = image.cropping(to: CGRect(x: 0, y: rows.lowerBound, width: image.width, height: rows.count))
        else { return nil }
        return stack([cropped], width: image.width, colorSpace: image.colorSpace)
    }

    /// Draws images top to bottom, 1:1 in pixels, into a new image.
    static func stack(_ images: [CGImage], width: Int, colorSpace: CGColorSpace?) -> CGImage? {
        let total = images.reduce(0) { $0 + $1.height }
        guard total > 0, width > 0,
              let context = makeContext(width: width, height: total, colorSpace: colorSpace) else { return nil }
        context.interpolationQuality = .none
        var top = 0
        for image in images {
            let rect = CGRect(x: 0, y: total - top - image.height, width: image.width, height: image.height)
            context.draw(image, in: rect)
            top += image.height
        }
        return context.makeImage()
    }

    private static func makeContext(width: Int, height: Int, colorSpace: CGColorSpace?) -> CGContext? {
        let fallback = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let candidates = [colorSpace, fallback].compactMap(\.self)
        for space in candidates {
            if let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: 0, space: space, bitmapInfo: bitmapInfo
            ) {
                return context
            }
        }
        return nil
    }
}
