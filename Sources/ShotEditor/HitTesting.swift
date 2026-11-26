import CoreGraphics
import Foundation

enum HandleKind: Equatable, Sendable {
    case start, end
    case topLeft, topRight, bottomLeft, bottomRight
}

/// Which part of an annotation a move drag affects.
enum MovePart: Equatable, Sendable {
    case whole, magnifierSource, magnifierCallout
}

@MainActor
enum HitTesting {
    /// Visual bounds of an annotation in document coordinates.
    static func bounds(of annotation: Annotation) -> CGRect {
        switch annotation.kind {
        case .text:
            return TextLayout.frame(for: annotation)
        case .counter:
            return circle(center: annotation.start, radius: TextLayout.counterRadius(for: annotation.style))
        case .pen:
            return pointsBounds(annotation.points).insetBy(dx: -annotation.style.lineWidth / 2, dy: -annotation.style.lineWidth / 2)
        case .arrow, .line:
            return annotation.rect.insetBy(dx: -annotation.style.lineWidth, dy: -annotation.style.lineWidth)
        case .magnifier:
            return annotation.rect.union(circle(center: annotation.callout, radius: annotation.calloutRadius))
        case .rectangle, .ellipse, .highlight, .blur, .pixelate, .spotlight, .fill, .image:
            return annotation.rect
        }
    }

    static func penBounds(of annotation: Annotation) -> CGRect { pointsBounds(annotation.points) }

    static func handles(for annotation: Annotation) -> [(kind: HandleKind, point: CGPoint)] {
        switch annotation.kind {
        case .arrow, .line:
            return [(.start, annotation.start), (.end, annotation.end)]
        case .text:
            let frame = TextLayout.frame(for: annotation)
            return [(.bottomRight, CGPoint(x: frame.maxX, y: frame.maxY))]
        case .counter:
            let radius = TextLayout.counterRadius(for: annotation.style)
            return [(.end, CGPoint(x: annotation.start.x + radius, y: annotation.start.y))]
        case .pen:
            return Resizing.cornerHandles(of: pointsBounds(annotation.points))
        default:
            return Resizing.cornerHandles(of: annotation.rect)
        }
    }

    static func handle(of annotation: Annotation, at point: CGPoint, tolerance: CGFloat) -> HandleKind? {
        handles(for: annotation)
            .filter { $0.point.distance(to: point) <= tolerance }
            .min { $0.point.distance(to: point) < $1.point.distance(to: point) }?
            .kind
    }

    /// Topmost annotation under `point`.
    static func topmost(in document: EditorDocument, at point: CGPoint, tolerance: CGFloat) -> Annotation? {
        document.annotations.last { hits($0, point: point, tolerance: tolerance) }
    }

    static func movePart(of annotation: Annotation, at point: CGPoint) -> MovePart {
        guard annotation.kind == .magnifier else { return .whole }
        return point.distance(to: annotation.callout) <= annotation.calloutRadius ? .magnifierCallout : .magnifierSource
    }

    static func hits(_ annotation: Annotation, point: CGPoint, tolerance: CGFloat) -> Bool {
        let reach = tolerance + annotation.style.lineWidth / 2
        switch annotation.kind {
        case .arrow, .line:
            return Geometry.distance(from: point, toSegment: annotation.start, annotation.end) <= reach + annotation.style.lineWidth
        case .pen:
            return hitsPolyline(annotation.points, point: point, reach: reach)
        case .rectangle:
            return annotation.style.filled
                ? annotation.rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
                : hitsRectBorder(annotation.rect, point: point, reach: reach)
        case .ellipse:
            return hitsEllipse(annotation.rect, filled: annotation.style.filled, point: point, reach: reach)
        case .magnifier:
            let source = CGPoint(x: annotation.rect.midX, y: annotation.rect.midY)
            return point.distance(to: source) <= annotation.sourceRadius + tolerance
                || point.distance(to: annotation.callout) <= annotation.calloutRadius + tolerance
        case .text, .counter, .highlight, .blur, .pixelate, .spotlight, .fill, .image:
            return bounds(of: annotation).insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    // MARK: - Helpers

    private static func circle(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private static func pointsBounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { rect, point in
            rect.union(CGRect(origin: point, size: .zero))
        }
    }

    private static func hitsPolyline(_ points: [CGPoint], point: CGPoint, reach: CGFloat) -> Bool {
        guard let first = points.first else { return false }
        guard points.count > 1 else { return first.distance(to: point) <= reach }
        return zip(points, points.dropFirst()).contains { a, b in
            Geometry.distance(from: point, toSegment: a, b) <= reach
        }
    }

    private static func hitsRectBorder(_ rect: CGRect, point: CGPoint, reach: CGFloat) -> Bool {
        let outer = rect.insetBy(dx: -reach, dy: -reach)
        let inner = rect.insetBy(dx: reach, dy: reach)
        return outer.contains(point) && (inner.isNull || inner.isEmpty || !inner.contains(point))
    }

    private static func hitsEllipse(_ rect: CGRect, filled: Bool, point: CGPoint, reach: CGFloat) -> Bool {
        let outer = rect.insetBy(dx: -reach, dy: -reach)
        guard ellipse(outer, contains: point) else { return false }
        if filled { return true }
        let inner = rect.insetBy(dx: reach, dy: reach)
        guard inner.width > 0, inner.height > 0 else { return true }
        return !ellipse(inner, contains: point)
    }

    private static func ellipse(_ rect: CGRect, contains point: CGPoint) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let dx = (point.x - rect.midX) / (rect.width / 2)
        let dy = (point.y - rect.midY) / (rect.height / 2)
        return dx * dx + dy * dy <= 1
    }
}
