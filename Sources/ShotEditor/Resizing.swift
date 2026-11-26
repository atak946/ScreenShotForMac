import CoreGraphics

/// Applies handle drags to annotations and crop rects. Always resizes from the
/// annotation as it was when the drag began (`original`) to avoid drift.
@MainActor
enum Resizing {
    private static let minimumPenSide: CGFloat = 1

    static func resize(_ original: Annotation, handle: HandleKind, to point: CGPoint, constrain: Bool) -> Annotation {
        switch original.kind {
        case .arrow, .line:
            let anchor = handle == .start ? original.end : original.start
            let target = constrain ? Geometry.snap45(from: anchor, to: point) : point
            return handle == .start ? original.with(start: target) : original.with(end: target)
        case .text:
            return resizeText(original, to: point)
        case .counter:
            var style = original.style
            style.fontSize = clampFont(original.start.distance(to: point) / TextLayout.counterRadiusFactor)
            return original.with(style: style)
        case .pen:
            return resizePen(original, handle: handle, to: point, constrain: constrain)
        case .image:
            let anchor = opposite(of: handle, in: original.rect)
            let target = constrain ? keepAspect(from: anchor, to: point, of: original.rect.size) : point
            return original.with(start: anchor, end: target)
        case .magnifier:
            let anchor = opposite(of: handle, in: original.rect)
            return original.with(start: anchor, end: Geometry.square(from: anchor, to: point))
        default:
            let anchor = opposite(of: handle, in: original.rect)
            let target = constrain ? Geometry.square(from: anchor, to: point) : point
            return original.with(start: anchor, end: target)
        }
    }

    /// `aspect` (width / height) locks the ratio; otherwise `constrain` keeps it square.
    static func resize(rect: CGRect, handle: HandleKind, to point: CGPoint, constrain: Bool, aspect: CGFloat? = nil) -> CGRect {
        let anchor = opposite(of: handle, in: rect)
        let target: CGPoint = if let aspect {
            Geometry.aspect(from: anchor, to: point, ratio: aspect)
        } else {
            constrain ? Geometry.square(from: anchor, to: point) : point
        }
        return Geometry.rect(from: anchor, to: target)
    }

    static func cornerHandles(of rect: CGRect) -> [(kind: HandleKind, point: CGPoint)] {
        [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY)),
        ]
    }

    // MARK: - Kind specific

    /// Dragging the bottom-right handle scales the font size.
    private static func resizeText(_ original: Annotation, to point: CGPoint) -> Annotation {
        let frame = TextLayout.frame(for: original)
        let originalHeight = max(frame.maxY - frame.minY, 1)
        let ratio = max((point.y - frame.minY) / originalHeight, 0.05)
        var style = original.style
        style.fontSize = clampFont(original.style.fontSize * ratio)
        return original.with(style: style)
    }

    private static func resizePen(_ original: Annotation, handle: HandleKind, to point: CGPoint, constrain: Bool) -> Annotation {
        let box = HitTesting.penBounds(of: original)
        let anchor = opposite(of: handle, in: box)
        let corner = cornerHandles(of: box).first { $0.kind == handle }?.point ?? point
        let width = corner.x - anchor.x
        let height = corner.y - anchor.y
        var scaleX = abs(width) < minimumPenSide ? 1 : (point.x - anchor.x) / width
        var scaleY = abs(height) < minimumPenSide ? 1 : (point.y - anchor.y) / height
        if constrain {
            let uniform = max(abs(scaleX), abs(scaleY))
            scaleX = scaleX < 0 ? -uniform : uniform
            scaleY = scaleY < 0 ? -uniform : uniform
        }
        let scaled = original.points.map { p in
            CGPoint(x: anchor.x + (p.x - anchor.x) * scaleX, y: anchor.y + (p.y - anchor.y) * scaleY)
        }
        return original.with(points: scaled).with(start: scaled.first ?? original.start, end: scaled.last ?? original.end)
    }

    private static func keepAspect(from anchor: CGPoint, to point: CGPoint, of size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return point }
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        let scale = max(abs(dx) / size.width, abs(dy) / size.height)
        return CGPoint(
            x: anchor.x + (dx < 0 ? -1 : 1) * size.width * scale,
            y: anchor.y + (dy < 0 ? -1 : 1) * size.height * scale
        )
    }

    private static func clampFont(_ size: CGFloat) -> CGFloat {
        min(max(size, AnnotationStyle.fontSizeRange.lowerBound), AnnotationStyle.fontSizeRange.upperBound)
    }

    private static func opposite(of handle: HandleKind, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft, .start: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight, .end: return CGPoint(x: rect.minX, y: rect.minY)
        }
    }
}
