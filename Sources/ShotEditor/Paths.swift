import CoreGraphics

enum ArrowPath {
    static func headLength(lineWidth: CGFloat, segmentLength: CGFloat, heads: Int = 1) -> CGFloat {
        min(max(lineWidth * 4.5, 12), segmentLength * (heads > 1 ? 0.4 : 0.6))
    }

    /// Tapered arrow: thin tail widening toward a sharp triangular head.
    static func tapered(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat) -> CGPath? {
        let delta = end - start
        let length = delta.length
        guard length > 1 else { return nil }
        let direction = delta.normalized
        let normal = direction.perpendicular

        let headLength = headLength(lineWidth: lineWidth, segmentLength: length)
        let headHalfWidth = headLength * 0.5
        let tailHalfWidth = max(lineWidth * 0.2, 0.5)
        let neckHalfWidth = max(lineWidth * 0.6, 1)
        let base = end - direction * headLength

        let path = CGMutablePath()
        path.move(to: start + normal * tailHalfWidth)
        path.addLine(to: base + normal * neckHalfWidth)
        path.addLine(to: base + normal * headHalfWidth - direction * (headLength * 0.12))
        path.addLine(to: end)
        path.addLine(to: base - normal * headHalfWidth - direction * (headLength * 0.12))
        path.addLine(to: base - normal * neckHalfWidth)
        path.addLine(to: start - normal * tailHalfWidth)
        path.closeSubpath()
        return path
    }

    /// Filled triangular head whose tip is `tip`, pointing along `direction`.
    static func head(tip: CGPoint, direction: CGPoint, length: CGFloat) -> CGPath {
        let normal = direction.perpendicular
        let base = tip - direction * length
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: base + normal * (length * 0.5) - direction * (length * 0.12))
        path.addLine(to: base + direction * (length * 0.15))
        path.addLine(to: base - normal * (length * 0.5) - direction * (length * 0.12))
        path.closeSubpath()
        return path
    }
}

/// Freehand pen path smoothed with quadratic curves through segment midpoints.
enum PenPath {
    static func smoothed(points: [CGPoint], start: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            if points.count == 1 { path.addLine(to: start) }
            return path
        }
        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }
}
