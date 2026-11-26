import CoreGraphics
import Foundation

/// Small vector helpers used by rendering, hit testing and interaction.
extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    func distance(to other: CGPoint) -> CGFloat { (self - other).length }

    var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : .zero
    }

    /// Perpendicular vector (rotated 90 degrees).
    var perpendicular: CGPoint { CGPoint(x: -y, y: x) }
}

enum Geometry {
    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// Distance from `point` to the segment `a`–`b`.
    static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = b - a
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        guard lengthSquared > 0 else { return point.distance(to: a) }
        let ap = point - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSquared))
        return point.distance(to: a + ab * t)
    }

    /// Constrains `end` so the rect spanned from `start` is a square.
    static func square(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
    }

    /// Largest point toward `end` whose box from `start` has `ratio` (width / height).
    static func aspect(from start: CGPoint, to end: CGPoint, ratio: CGFloat) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard ratio > 0 else { return end }
        var width = abs(dx)
        var height = abs(dy)
        if height * ratio > width { height = width / ratio } else { width = height * ratio }
        return CGPoint(x: start.x + (dx < 0 ? -width : width), y: start.y + (dy < 0 ? -height : height))
    }

    /// Snaps the segment `start`–`end` to the nearest 45 degree angle.
    static func snap45(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let delta = end - start
        let length = delta.length
        guard length > 0 else { return end }
        let step = CGFloat.pi / 4
        let angle = (atan2(delta.y, delta.x) / step).rounded() * step
        return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
    }

    static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }
}
