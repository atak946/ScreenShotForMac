import CoreGraphics
@testable import ShotMeasure
import ShotTestSupport
import Testing

/// 50x40 white image with a black box at x 10...29, y 5...24 and one near-white speck.
private func makeBuffer() throws -> PixelBuffer {
    let image = try #require(TestImages.make(width: 50, height: 40) { x, y in
        if (10...29).contains(x), (5...24).contains(y) {
            return .black
        }
        if x == 40, y == 30 {
            return TestPixel(250, 250, 250)
        }
        return .white
    })
    return try #require(PixelBuffer(image: image))
}

@Suite("EdgeScanner")
struct EdgeScannerTests {
    @Test("Span inside a solid box stops at its edges")
    func spanInsideBox() throws {
        let scanner = try EdgeScanner(buffer: makeBuffer(), tolerance: EdgeScanner.defaultTolerance)
        #expect(scanner.span(around: PixelPoint(x: 15, y: 10)) == PixelRect(minX: 10, minY: 5, maxX: 29, maxY: 24))
    }

    @Test("Span on the background runs to the image or box edges")
    func spanOnBackground() throws {
        let scanner = try EdgeScanner(buffer: makeBuffer(), tolerance: EdgeScanner.defaultTolerance)
        #expect(scanner.span(around: PixelPoint(x: 2, y: 2)) == PixelRect(minX: 0, minY: 0, maxX: 49, maxY: 39))
        #expect(scanner.span(around: PixelPoint(x: 5, y: 10)) == PixelRect(minX: 0, minY: 0, maxX: 9, maxY: 39))
        #expect(scanner.span(around: PixelPoint(x: 20, y: 30)) == PixelRect(minX: 0, minY: 25, maxX: 49, maxY: 39))
    }

    @Test("Tolerance decides whether a speck is an edge")
    func tolerance() throws {
        let buffer = try makeBuffer()
        let tolerant = EdgeScanner(buffer: buffer, tolerance: 12)
        #expect(tolerant.span(around: PixelPoint(x: 45, y: 30)).minX == 0)
        let strict = EdgeScanner(buffer: buffer, tolerance: 0)
        #expect(strict.span(around: PixelPoint(x: 45, y: 30)).minX == 41)
    }

    @Test("Content bounds shrink to the non-background area")
    func contentBounds() throws {
        let scanner = try EdgeScanner(buffer: makeBuffer(), tolerance: 12)
        let full = PixelRect(minX: 0, minY: 0, maxX: 35, maxY: 35)
        #expect(scanner.contentBounds(in: full) == PixelRect(minX: 10, minY: 5, maxX: 29, maxY: 24))
        #expect(scanner.contentBounds(in: PixelRect(minX: 30, minY: 25, maxX: 49, maxY: 39)) == nil)
        let strict = try EdgeScanner(buffer: makeBuffer(), tolerance: 0)
        #expect(strict.contentBounds(in: PixelRect(minX: 30, minY: 25, maxX: 49, maxY: 39)) == PixelRect(
            minX: 40,
            minY: 30,
            maxX: 40,
            maxY: 30
        ))
    }
}

@Suite("PixelBuffer")
struct PixelBufferTests {
    @Test("Colors, bounds and clamping")
    func colors() throws {
        let buffer = try makeBuffer()
        #expect(buffer.width == 50)
        #expect(buffer.height == 40)
        #expect(buffer.color(x: 15, y: 10) == RGBColor(red: 0, green: 0, blue: 0))
        #expect(buffer.color(x: 0, y: 0) == RGBColor(red: 255, green: 255, blue: 255))
        #expect(buffer.contains(x: 49, y: 39))
        #expect(!buffer.contains(x: 50, y: 0))
        #expect(!buffer.contains(x: -1, y: 0))
        #expect(buffer.clamped(x: -5, y: 100) == PixelPoint(x: 0, y: 39))
        #expect(buffer.color(x: 999, y: 999) == buffer.color(x: 49, y: 39))
    }

    @Test("Rect and color helpers")
    func helpers() {
        let rect = PixelRect(minX: 2, minY: 3, maxX: 4, maxY: 3)
        #expect(rect.width == 3)
        #expect(rect.height == 1)
        #expect(rect.contains(PixelPoint(x: 4, y: 3)))
        #expect(!rect.contains(PixelPoint(x: 5, y: 3)))
        #expect(RGBColor(red: 10, green: 200, blue: 30).distance(to: RGBColor(red: 20, green: 190, blue: 0)) == 30)
    }
}

@Suite("MeasureFormatter")
struct MeasureFormatterTests {
    @Test("Labels in points and pixels")
    func labels() {
        let points = MeasureFormatter(scaleX: 2, scaleY: 2, primary: .points, showsSecondary: false)
        #expect(points.width(240) == "120 pt")
        #expect(points.height(97) == "48.5 pt")
        let both = MeasureFormatter(scaleX: 2, scaleY: 2, primary: .points, showsSecondary: true)
        #expect(both.width(240) == "120 pt · 240 px")
        let pixels = MeasureFormatter(scaleX: 2, scaleY: 2, primary: .pixels, showsSecondary: true)
        #expect(pixels.width(240) == "240 px · 120 pt")
    }

    @Test("Size and copy text")
    func sizeAndCopy() {
        let points = MeasureFormatter(scaleX: 2, scaleY: 2, primary: .points, showsSecondary: false)
        #expect(points.size(width: 240, height: 97) == "120 × 48.5 pt  ·  240 × 97 px")
        #expect(points.copyText(width: 240, height: 97) == "120 × 48.5")
        let pixels = MeasureFormatter(scaleX: 2, scaleY: 2, primary: .pixels, showsSecondary: false)
        #expect(pixels.size(width: 240, height: 97) == "240 × 97 px  ·  120 × 48.5 pt")
        #expect(pixels.copyText(width: 240, height: 97) == "240 × 97")
    }

    @Test("Numbers are integers when whole, otherwise one decimal")
    func numbers() {
        #expect(MeasureFormatter.number(2) == "2")
        #expect(MeasureFormatter.number(1.25) == "1.3")
        #expect(MeasureFormatter.number(0.04) == "0")
        #expect(MeasureUnit.points.toggled == .pixels)
        #expect(MeasureUnit.pixels.suffix == "px")
    }
}
