import CoreGraphics
@testable import ShotScrolling
import ShotTestSupport
import Testing

/// Deterministic, non-repeating gray "page" content: every 8-px block of every row differs.
private func pageValue(x: Int, y: Int, seed: Int = 0) -> UInt8 {
    var hash = UInt64(truncatingIfNeeded: y &* 73_856_093 ^ (x / 8) &* 19_349_663 ^ seed &* 83_492_791)
    hash ^= hash >> 13
    hash = hash &* 0x5BD1_E995
    hash ^= hash >> 15
    return UInt8(truncatingIfNeeded: hash)
}

private let frameWidth = 256
private let frameHeight = 200
private let headerHeight = 30

/// A viewport of the page scrolled by `offset` rows, optionally with a sticky header.
private func frame(offset: Int, header: Bool = false, seed: Int = 0) -> CGImage? {
    TestImages.make(width: frameWidth, height: frameHeight) { x, y in
        if header, y < headerHeight {
            let value = UInt8(40 + (x / 16) * 4)
            return TestPixel(value, value, value)
        }
        let row = header ? y - headerHeight + offset : y + offset
        let value = pageValue(x: x, y: row, seed: seed)
        return TestPixel(value, value, value)
    }
}

private func stitchFrame(_ image: CGImage) throws -> StitchFrame {
    try StitchFrame(image: image, signatures: #require(RowSignatures.make(from: image)))
}

@Suite("RowSignatures & OffsetEstimator")
struct OffsetEstimatorTests {
    @Test("Signatures have one row per pixel row")
    func signatures() throws {
        let image = try #require(frame(offset: 0))
        let signatures = try #require(RowSignatures.make(from: image))
        #expect(signatures.rowCount == frameHeight)
        #expect(signatures.buckets.count == frameHeight * RowSignatures.bucketCount)
        #expect(signatures.difference(row: 10, to: signatures, row: 10) == 0)
        #expect(signatures.difference(row: 10, to: signatures, row: 11) > RowSignatures.bucketCount)
        #expect(try RowSignatures.make(from: #require(TestImages.solid(width: 1, height: 5, color: .red))) == nil)
    }

    @Test("Identical frames have no static bands")
    func identical() throws {
        let image = try #require(frame(offset: 0))
        let signatures = try #require(RowSignatures.make(from: image))
        #expect(OffsetEstimator.staticBands(previous: signatures, current: signatures) == nil)
    }

    @Test("Sticky header is detected as a static band")
    func header() throws {
        let previousImage = try #require(frame(offset: 0, header: true))
        let currentImage = try #require(frame(offset: 40, header: true))
        let previous = try #require(RowSignatures.make(from: previousImage))
        let current = try #require(RowSignatures.make(from: currentImage))
        let bands = try #require(OffsetEstimator.staticBands(previous: previous, current: current))
        #expect(bands.header == headerHeight)
        #expect(bands.footer == 0)
        #expect(bands.scrollingRange(height: frameHeight) == headerHeight..<frameHeight)
    }

    @Test("Known downward and upward shifts are recovered", arguments: [7, 25, 64])
    func knownShift(shift: Int) throws {
        let top = try stitchFrame(#require(frame(offset: 0)))
        let scrolled = try stitchFrame(#require(frame(offset: shift)))
        let bands = StaticBands(header: 0, footer: 0)
        #expect(OffsetEstimator.estimate(previous: top, current: scrolled, bands: bands) == .shift(shift))
        #expect(OffsetEstimator.estimate(previous: scrolled, current: top, bands: bands) == .shift(-shift))
    }

    @Test("Unrelated frames do not match")
    func noMatch() throws {
        let first = try stitchFrame(#require(frame(offset: 0, seed: 1)))
        let second = try stitchFrame(#require(frame(offset: 0, seed: 2)))
        #expect(OffsetEstimator.estimate(previous: first, current: second, bands: StaticBands(header: 0, footer: 0)) == .noMatch)
    }
}

@Suite("ImageStitcher")
struct ImageStitcherTests {
    @Test("Frames with a sticky header stitch into one continuous image")
    func stitchWithHeader() async throws {
        let stitcher = ImageStitcher()
        let first = try await stitcher.add(SendableImage(cgImage: #require(frame(offset: 0, header: true))))
        #expect(first.status == .started)
        let second = try await stitcher.add(SendableImage(cgImage: #require(frame(offset: 40, header: true))))
        #expect(second.status == .appended(40))
        let third = try await stitcher.add(SendableImage(cgImage: #require(frame(offset: 90, header: true))))
        #expect(third.status == .appended(50))
        #expect(third.pixelHeight == frameHeight + 90)
        #expect(third.frameHeight == frameHeight)

        let composed = try #require(await stitcher.compose()).cgImage
        #expect(composed.width == frameWidth)
        #expect(composed.height == frameHeight + 90)
        let pixels = try #require(TestImages.pixels(of: composed))
        let header = pixels[5 * frameWidth + 20]
        #expect(header.red == UInt8(40 + (20 / 16) * 4), "header appears once at the top")
        for y in stride(from: headerHeight, to: composed.height, by: 7) {
            for x in [0, 77, 200] {
                let expected = pageValue(x: x, y: y - headerHeight)
                #expect(abs(Int(pixels[y * frameWidth + x].red) - Int(expected)) <= 1, "row \(y) column \(x)")
            }
        }
    }

    @Test("Unchanged, scrolled-up and resized frames are reported and ignored")
    func ignoredFrames() async throws {
        let stitcher = ImageStitcher()
        let base = try #require(frame(offset: 30))
        _ = await stitcher.add(SendableImage(cgImage: base))
        #expect(await stitcher.add(SendableImage(cgImage: base)).status == .unchanged)
        #expect(try await stitcher.add(SendableImage(cgImage: #require(frame(offset: 0)))).status == .scrolledUp)
        let small = try #require(TestImages.solid(width: 100, height: 100, color: .red))
        #expect(await stitcher.add(SendableImage(cgImage: small)).status == .noMatch)
        let composed = try #require(await stitcher.compose()).cgImage
        #expect(composed.height == frameHeight)
    }

    @Test("Nothing captured composes to nil")
    func empty() async {
        #expect(await ImageStitcher().compose() == nil)
    }

    @Test("ImageOps stacks images top to bottom")
    func stack() throws {
        let red = try #require(TestImages.solid(width: 4, height: 2, color: .red))
        let blue = try #require(TestImages.solid(width: 4, height: 3, color: .blue))
        let stacked = try #require(ImageOps.stack([red, blue], width: 4, colorSpace: red.colorSpace))
        #expect(stacked.height == 5)
        #expect(TestImages.pixel(of: stacked, x: 1, y: 1) == .red)
        #expect(TestImages.pixel(of: stacked, x: 1, y: 4) == .blue)
        let rows = try #require(ImageOps.copyRows(of: stacked, rows: 2..<5))
        #expect(rows.height == 3)
        #expect(TestImages.pixel(of: rows, x: 0, y: 0) == .blue)
        #expect(ImageOps.copyRows(of: stacked, rows: 2..<2) == nil)
    }
}
