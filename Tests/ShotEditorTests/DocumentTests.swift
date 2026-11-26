import CoreGraphics
@testable import ShotEditor
import ShotTestSupport
import Testing

/// 200x100 px document at 2x (100x50 pt).
func makeDocument(width: Int = 200, height: Int = 100, scale: CGFloat = 2) throws -> EditorDocument {
    let image = try #require(TestImages.solid(width: width, height: height, color: .red))
    return EditorDocument(baseImage: image, scale: scale)
}

func rectangle(_ rect: CGRect, filled: Bool = false) -> Annotation {
    var style = AnnotationStyle.default
    style.filled = filled
    return Annotation(kind: .rectangle, start: rect.origin, end: CGPoint(x: rect.maxX, y: rect.maxY), style: style)
}

@MainActor
@Suite("HitTesting")
struct HitTestingTests {
    @Test("Outlined rectangles are hit on the border only")
    func outlinedRectangle() {
        let shape = rectangle(CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(HitTesting.hits(shape, point: CGPoint(x: 1, y: 50), tolerance: 4))
        #expect(!HitTesting.hits(shape, point: CGPoint(x: 50, y: 50), tolerance: 4))
        #expect(!HitTesting.hits(shape, point: CGPoint(x: 150, y: 50), tolerance: 4))
    }

    @Test("Filled rectangles are hit inside")
    func filledRectangle() {
        let shape = rectangle(CGRect(x: 0, y: 0, width: 100, height: 100), filled: true)
        #expect(HitTesting.hits(shape, point: CGPoint(x: 50, y: 50), tolerance: 4))
        #expect(HitTesting.hits(shape, point: CGPoint(x: 102, y: 50), tolerance: 4))
    }

    @Test("Ellipse outline")
    func ellipse() {
        let shape = Annotation(kind: .ellipse, start: .zero, end: CGPoint(x: 100, y: 50), style: .default)
        #expect(HitTesting.hits(shape, point: CGPoint(x: 0, y: 25), tolerance: 3))
        #expect(!HitTesting.hits(shape, point: CGPoint(x: 50, y: 25), tolerance: 3))
        #expect(!HitTesting.hits(shape, point: CGPoint(x: 2, y: 2), tolerance: 3), "corner is outside the ellipse")
    }

    @Test("Lines are hit near the segment")
    func line() {
        let line = Annotation(kind: .line, start: .zero, end: CGPoint(x: 100, y: 0), style: .default)
        #expect(HitTesting.hits(line, point: CGPoint(x: 50, y: 5), tolerance: 4))
        #expect(!HitTesting.hits(line, point: CGPoint(x: 50, y: 30), tolerance: 4))
    }

    @Test("Pen polyline")
    func pen() {
        let pen = Annotation(kind: .pen, start: .zero, points: [.zero, CGPoint(x: 50, y: 50)], style: .default)
        #expect(HitTesting.hits(pen, point: CGPoint(x: 25, y: 26), tolerance: 3))
        #expect(!HitTesting.hits(pen, point: CGPoint(x: 50, y: 0), tolerance: 3))
        #expect(HitTesting.penBounds(of: pen) == CGRect(x: 0, y: 0, width: 50, height: 50))
    }

    @Test("Topmost annotation wins")
    func topmost() throws {
        let bottom = rectangle(CGRect(x: 0, y: 0, width: 50, height: 50), filled: true)
        let top = rectangle(CGRect(x: 10, y: 10, width: 50, height: 50), filled: true)
        let document = try makeDocument().adding([bottom, top])
        #expect(HitTesting.topmost(in: document, at: CGPoint(x: 20, y: 20), tolerance: 2)?.id == top.id)
        #expect(HitTesting.topmost(in: document, at: CGPoint(x: 5, y: 5), tolerance: 2)?.id == bottom.id)
        #expect(HitTesting.topmost(in: document, at: CGPoint(x: 90, y: 45), tolerance: 2) == nil)
    }

    @Test("Handles are found within tolerance")
    func handles() {
        let shape = rectangle(CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(HitTesting.handle(of: shape, at: CGPoint(x: 98, y: 101), tolerance: 5) == .bottomRight)
        #expect(HitTesting.handle(of: shape, at: CGPoint(x: 50, y: 50), tolerance: 5) == nil)
        let arrow = Annotation(kind: .arrow, start: .zero, end: CGPoint(x: 10, y: 10), style: .default)
        #expect(HitTesting.handle(of: arrow, at: CGPoint(x: 1, y: 1), tolerance: 3) == .start)
    }

    @Test("Magnifier parts")
    func magnifierParts() {
        let magnifier = Annotation(
            kind: .magnifier, start: .zero, end: CGPoint(x: 20, y: 20), style: .default, callout: CGPoint(x: 100, y: 100)
        )
        #expect(HitTesting.movePart(of: magnifier, at: CGPoint(x: 105, y: 100)) == .magnifierCallout)
        #expect(HitTesting.movePart(of: magnifier, at: CGPoint(x: 10, y: 10)) == .magnifierSource)
        #expect(HitTesting.movePart(of: rectangle(.zero), at: .zero) == .whole)
        #expect(HitTesting.hits(magnifier, point: CGPoint(x: 100, y: 118), tolerance: 0))
    }
}

@Suite("EditorDocument")
struct EditorDocumentTests {
    @Test("Bounds, padding and crop define the output rect")
    func outputRect() throws {
        let document = try makeDocument()
        #expect(document.bounds == CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(document.outputRect == document.bounds)
        let padded = document.withPadding(10)
        #expect(padded.canvasRect == CGRect(x: -10, y: -10, width: 120, height: 70))
        #expect(padded.withCrop(CGRect(x: -50, y: 0, width: 100, height: 10)).outputRect == CGRect(x: -10, y: 0, width: 60, height: 10))
    }

    @Test("Shrinking the padding clips or drops the crop")
    func paddingDropsCrop() throws {
        let document = try makeDocument().withPadding(20).withCrop(CGRect(x: -20, y: -20, width: 10, height: 10))
        #expect(document.withPadding(0).cropRect == nil)
        let partial = try makeDocument().withPadding(20).withCrop(CGRect(x: -20, y: 0, width: 40, height: 10))
        #expect(partial.withPadding(0).cropRect == CGRect(x: 0, y: 0, width: 20, height: 10))
        #expect(try makeDocument().withPadding(-5).canvasPadding == 0)
    }

    @Test("Counter numbering and immutable edits")
    func edits() throws {
        let counter = Annotation(kind: .counter, start: .zero, number: 4, style: .default)
        let shape = rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
        let original = try makeDocument()
        let document = original.adding([counter, shape])
        #expect(original.annotations.isEmpty)
        #expect(document.nextCounterNumber == 5)
        #expect(try makeDocument().nextCounterNumber == 1)

        let moved = document.moving(ids: [shape.id], by: CGPoint(x: 5, y: 5))
        #expect(moved.annotation(id: shape.id)?.start == CGPoint(x: 5, y: 5))
        #expect(moved.annotation(id: counter.id)?.start == .zero)
        #expect(document.removing(ids: [counter.id, shape.id]).annotations.isEmpty)
        #expect(document.withSpotlightOpacity(3).spotlightOpacity == 1)
    }
}

@MainActor
@Suite("DocumentTransform")
struct DocumentTransformTests {
    private let size = CGSize(width: 30, height: 20)

    @Test("Output sizes")
    func outputSizes() {
        #expect(DocumentTransform.rotateLeft.outputSize(for: size) == CGSize(width: 20, height: 30))
        #expect(DocumentTransform.rotateRight.outputSize(for: size) == CGSize(width: 20, height: 30))
        #expect(DocumentTransform.flipHorizontal.outputSize(for: size) == size)
    }

    @Test("Point mappings")
    func mappings() {
        let point = CGPoint(x: 5, y: 2)
        #expect(point.applying(DocumentTransform.rotateRight.affine(for: size)) == CGPoint(x: 18, y: 5))
        #expect(point.applying(DocumentTransform.rotateLeft.affine(for: size)) == CGPoint(x: 2, y: 25))
        #expect(point.applying(DocumentTransform.flipHorizontal.affine(for: size)) == CGPoint(x: 25, y: 2))
    }

    @Test("Rotate right then left, and flip twice, round-trip points")
    func roundTrips() {
        let point = CGPoint(x: 7, y: 3)
        let right = point.applying(DocumentTransform.rotateRight.affine(for: size))
        let back = right.applying(DocumentTransform.rotateLeft.affine(for: DocumentTransform.rotateRight.outputSize(for: size)))
        #expect(back == point)
        let flipped = point.applying(DocumentTransform.flipHorizontal.affine(for: size))
        #expect(flipped.applying(DocumentTransform.flipHorizontal.affine(for: size)) == point)
    }

    @Test("Rotating the bitmap moves pixels clockwise")
    func rotateBitmap() throws {
        let image = try #require(TestImages.make(width: 3, height: 2) { x, y in x == 0 && y == 0 ? .blue : .white })
        let rotated = try #require(DocumentTransform.rotateRight.apply(to: image))
        #expect(rotated.width == 2)
        #expect(rotated.height == 3)
        #expect(TestImages.pixel(of: rotated, x: 1, y: 0) == .blue)
        #expect(TestImages.pixel(of: rotated, x: 0, y: 0) == .white)

        let flipped = try #require(DocumentTransform.flipHorizontal.apply(to: image))
        #expect(TestImages.pixel(of: flipped, x: 2, y: 0) == .blue)
    }

    @Test("Four right rotations restore annotations and crop")
    func documentRoundTrip() throws {
        let shape = rectangle(CGRect(x: 10, y: 5, width: 20, height: 10))
        var document = try makeDocument().adding(shape).withCrop(CGRect(x: 0, y: 0, width: 60, height: 40))
        for _ in 0..<4 {
            document = try #require(document.transformed(.rotateRight))
        }
        #expect(document.baseImage.width == 200)
        #expect(document.baseImage.height == 100)
        #expect(document.annotations.first?.rect == shape.rect)
        #expect(document.cropRect == CGRect(x: 0, y: 0, width: 60, height: 40))

        let once = try #require(try makeDocument().adding(shape).transformed(.rotateRight))
        #expect(once.bounds.size == CGSize(width: 50, height: 100))
        #expect(once.annotations.first?.rect == CGRect(x: 35, y: 10, width: 10, height: 20))
    }
}
