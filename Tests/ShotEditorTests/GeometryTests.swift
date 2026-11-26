import CoreGraphics
@testable import ShotEditor
import Testing

private func approx(_ lhs: CGPoint, _ rhs: CGPoint, tolerance: CGFloat = 0.001) -> Bool {
    abs(lhs.x - rhs.x) <= tolerance && abs(lhs.y - rhs.y) <= tolerance
}

@Suite("Geometry")
struct GeometryTests {
    @Test("Rect from any two corners is normalized")
    func rectFromPoints() {
        #expect(Geometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 0, y: 5)) == CGRect(x: 0, y: 5, width: 10, height: 15))
    }

    @Test("Distance to a segment")
    func segmentDistance() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 10, y: 0)
        #expect(Geometry.distance(from: CGPoint(x: 5, y: 5), toSegment: a, b) == 5)
        #expect(Geometry.distance(from: CGPoint(x: 13, y: 4), toSegment: a, b) == 5)
        #expect(Geometry.distance(from: CGPoint(x: 3, y: 4), toSegment: a, a) == 5)
    }

    @Test("Square constraint keeps the drag direction")
    func square() {
        #expect(Geometry.square(from: .zero, to: CGPoint(x: 30, y: 10)) == CGPoint(x: 30, y: 30))
        #expect(Geometry.square(from: .zero, to: CGPoint(x: -5, y: 20)) == CGPoint(x: -20, y: 20))
    }

    @Test("Aspect constraint picks the largest box inside the drag")
    func aspect() {
        #expect(Geometry.aspect(from: .zero, to: CGPoint(x: 100, y: 100), ratio: 2) == CGPoint(x: 100, y: 50))
        #expect(Geometry.aspect(from: .zero, to: CGPoint(x: -100, y: 10), ratio: 2) == CGPoint(x: -20, y: 10))
        #expect(Geometry.aspect(from: .zero, to: CGPoint(x: 7, y: 3), ratio: 0) == CGPoint(x: 7, y: 3))
    }

    @Test("45 degree snapping keeps the length")
    func snap45() {
        let snapped = Geometry.snap45(from: .zero, to: CGPoint(x: 10, y: 1))
        #expect(approx(snapped, CGPoint(x: CGPoint(x: 10, y: 1).length, y: 0)))
        let diagonal = Geometry.snap45(from: .zero, to: CGPoint(x: 10, y: 9))
        #expect(abs(diagonal.x - diagonal.y) < 0.001)
        #expect(Geometry.snap45(from: .zero, to: .zero) == .zero)
    }

    @Test("Clamp to rect")
    func clamp() {
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(Geometry.clamp(CGPoint(x: -5, y: 20), to: rect) == CGPoint(x: 0, y: 10))
        #expect(Geometry.clamp(CGPoint(x: 5, y: 5), to: rect) == CGPoint(x: 5, y: 5))
    }

    @Test("Vector helpers")
    func vectors() {
        #expect(CGPoint(x: 3, y: 4).length == 5)
        #expect(CGPoint(x: 0, y: 5).normalized == CGPoint(x: 0, y: 1))
        #expect(CGPoint.zero.normalized == .zero)
        #expect(CGPoint(x: 1, y: 2).perpendicular == CGPoint(x: -2, y: 1))
    }
}

@MainActor
@Suite("Resizing")
struct ResizingTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    @Test("Free, square and aspect-locked rect resize")
    func rectResize() {
        let point = CGPoint(x: 50, y: 40)
        #expect(Resizing.resize(rect: rect, handle: .bottomRight, to: point, constrain: false) == CGRect(x: 0, y: 0, width: 50, height: 40))
        #expect(Resizing.resize(rect: rect, handle: .bottomRight, to: point, constrain: true) == CGRect(x: 0, y: 0, width: 50, height: 50))
        #expect(
            Resizing.resize(rect: rect, handle: .bottomRight, to: point, constrain: true, aspect: 2)
                == CGRect(x: 0, y: 0, width: 50, height: 25)
        )
        #expect(
            Resizing.resize(rect: rect, handle: .topLeft, to: CGPoint(x: 20, y: 30), constrain: false)
                == CGRect(x: 20, y: 30, width: 80, height: 70)
        )
        #expect(
            Resizing.resize(rect: rect, handle: .topRight, to: CGPoint(x: 60, y: 10), constrain: false)
                == CGRect(x: 0, y: 10, width: 60, height: 90)
        )
    }

    @Test("Dragging past the anchor flips the rect")
    func flippedDrag() {
        let result = Resizing.resize(rect: rect, handle: .bottomRight, to: CGPoint(x: -20, y: -10), constrain: false)
        #expect(result == CGRect(x: -20, y: -10, width: 20, height: 10))
    }

    @Test("Arrow end snaps to 45 degrees when constrained")
    func arrowConstrain() {
        let arrow = Annotation(kind: .arrow, start: .zero, end: CGPoint(x: 10, y: 0), style: .default)
        let resized = Resizing.resize(arrow, handle: .end, to: CGPoint(x: 20, y: 1), constrain: true)
        #expect(resized.start == .zero)
        #expect(abs(resized.end.y) < 0.001)
        let free = Resizing.resize(arrow, handle: .start, to: CGPoint(x: 3, y: 4), constrain: false)
        #expect(free.start == CGPoint(x: 3, y: 4))
        #expect(free.end == CGPoint(x: 10, y: 0))
    }

    @Test("Image keeps its aspect ratio when constrained")
    func imageAspect() {
        let image = Annotation(kind: .image, start: .zero, end: CGPoint(x: 100, y: 50), style: .default)
        let resized = Resizing.resize(image, handle: .bottomRight, to: CGPoint(x: 300, y: 60), constrain: true)
        #expect(resized.rect == CGRect(x: 0, y: 0, width: 300, height: 150))
    }

    @Test("Magnifier stays square")
    func magnifierSquare() {
        let magnifier = Annotation(kind: .magnifier, start: .zero, end: CGPoint(x: 40, y: 40), style: .default)
        let resized = Resizing.resize(magnifier, handle: .bottomRight, to: CGPoint(x: 80, y: 30), constrain: false)
        #expect(resized.rect.width == resized.rect.height)
        #expect(resized.rect.width == 80)
    }

    @Test("Pen strokes scale around the opposite corner")
    func penScale() {
        let pen = Annotation(
            kind: .pen, start: .zero, end: CGPoint(x: 20, y: 0),
            points: [.zero, CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 0)], style: .default
        )
        let resized = Resizing.resize(pen, handle: .bottomRight, to: CGPoint(x: 40, y: 20), constrain: false)
        #expect(resized.points == [.zero, CGPoint(x: 20, y: 20), CGPoint(x: 40, y: 0)])
        #expect(resized.start == .zero)
        #expect(resized.end == CGPoint(x: 40, y: 0))
    }

    @Test("Corner handles of a rect")
    func cornerHandles() {
        let handles = Resizing.cornerHandles(of: CGRect(x: 1, y: 2, width: 3, height: 4))
        #expect(handles.map(\.kind) == [.topLeft, .topRight, .bottomLeft, .bottomRight])
        #expect(handles.map(\.point) == [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 2), CGPoint(x: 1, y: 6), CGPoint(x: 4, y: 6)])
    }
}
