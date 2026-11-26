import AppKit

/// One of the eight resize handles around a selection.
enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// Handle center for a rect in AppKit coordinates (top = maxY).
    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .top: return CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    @MainActor var cursor: NSCursor {
        switch self {
        case .left, .right: return .resizeLeftRight
        case .top, .bottom: return .resizeUpDown
        default: return .crosshair
        }
    }

    fileprivate var movesMinX: Bool { [.topLeft, .left, .bottomLeft].contains(self) }
    fileprivate var movesMaxX: Bool { [.topRight, .right, .bottomRight].contains(self) }
    fileprivate var movesMinY: Bool { [.bottomLeft, .bottom, .bottomRight].contains(self) }
    fileprivate var movesMaxY: Bool { [.topLeft, .top, .topRight].contains(self) }
}

/// Pure geometry for creating, moving and resizing a selection in global AppKit points.
enum SelectionGeometry {
    static let handleHitRadius: CGFloat = 7
    static let handleDrawSize: CGFloat = 9

    static func handle(at point: CGPoint, in rect: CGRect) -> SelectionHandle? {
        SelectionHandle.allCases.first { handle in
            let center = handle.point(in: rect)
            return abs(center.x - point.x) <= handleHitRadius && abs(center.y - point.y) <= handleHitRadius
        }
    }

    /// Rect spanned by an anchor and the cursor, optionally constrained to a square, clipped to `bounds`.
    static func spanning(anchor: CGPoint, cursor: CGPoint, square: Bool, bounds: CGRect) -> CGRect? {
        var dx = cursor.x - anchor.x
        var dy = cursor.y - anchor.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        let end = CGPoint(x: anchor.x + dx, y: anchor.y + dy)
        return clip(CGRect(corner: anchor, corner: end), to: bounds)
    }

    /// Moves `rect` by a delta, keeping it fully inside `bounds`.
    static func move(_ rect: CGRect, by delta: CGVector, within bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX + delta.dx, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY + delta.dy, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Drags one handle of `original` by `delta`. Edges may cross; the result is standardized.
    static func resize(
        _ original: CGRect,
        handle: SelectionHandle,
        by delta: CGVector,
        within bounds: CGRect
    ) -> CGRect? {
        var minX = original.minX, maxX = original.maxX
        var minY = original.minY, maxY = original.maxY
        if handle.movesMinX { minX += delta.dx }
        if handle.movesMaxX { maxX += delta.dx }
        if handle.movesMinY { minY += delta.dy }
        if handle.movesMaxY { maxY += delta.dy }
        let rect = CGRect(corner: CGPoint(x: minX, y: minY), corner: CGPoint(x: maxX, y: maxY))
        return clip(rect, to: bounds)
    }

    /// Keyboard resize keeping the top-left corner fixed. Positive values grow.
    static func grow(_ rect: CGRect, width dw: CGFloat, height dh: CGFloat, within bounds: CGRect) -> CGRect {
        let width = max(1, rect.width + dw)
        let height = max(1, rect.height + dh)
        let grown = CGRect(x: rect.minX, y: rect.maxY - height, width: width, height: height)
        return clip(grown, to: bounds) ?? rect
    }

    static func clip(_ rect: CGRect, to bounds: CGRect) -> CGRect? {
        let clipped = rect.intersection(bounds)
        return clipped.isNull ? nil : clipped
    }
}
