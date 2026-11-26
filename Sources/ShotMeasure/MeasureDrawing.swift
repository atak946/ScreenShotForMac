import AppKit
import ShotCore

/// Straight line between two window-local points.
struct Segment: Equatable, Sendable {
    let start: CGPoint
    let end: CGPoint

    var midpoint: CGPoint { CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2) }
    var isHorizontal: Bool { start.y == end.y }
}

/// Edge-detected crosshair around the cursor.
struct HoverGuide: Equatable, Sendable {
    let horizontal: Segment
    let vertical: Segment
    let horizontalLabel: String
    let verticalLabel: String
}

/// Dragged (or snapped) measurement box.
struct BoxGuide: Equatable, Sendable {
    let rect: CGRect
    let label: String
    let isSnapped: Bool
}

/// Short transient message near the cursor, e.g. "Copied".
struct Badge: Equatable, Sendable {
    let text: String
    let anchor: CGPoint
}

/// Everything one overlay draws, in window-local points.
struct MeasureScene: Equatable, Sendable {
    let hover: HoverGuide?
    let box: BoxGuide?
    let badge: Badge?

    static let empty = MeasureScene(hover: nil, box: nil, badge: nil)
}

/// Stateless renderer for the guide lines of a `MeasureScene`. Must be called inside
/// `NSView.draw(_:)`. Labels are glass pills laid out by `MeasureLabelLayout`.
@MainActor
enum MeasureDrawing {
    private static var accent: NSColor { DS.Palette.accent }
    private static let outline = NSColor.black.withAlphaComponent(0.6)
    private static let lineWidth: CGFloat = 1
    private static let outlineWidth: CGFloat = 3
    private static let capLength: CGFloat = 7

    static func draw(_ scene: MeasureScene) {
        if let box = scene.box { drawBox(box) }
        if let hover = scene.hover { drawHover(hover) }
    }

    private static func drawHover(_ hover: HoverGuide) {
        let path = NSBezierPath()
        [hover.horizontal, hover.vertical].forEach { appendSegment($0, to: path) }
        strokeOutlined(path)
    }

    private static func drawBox(_ box: BoxGuide) {
        accent.withAlphaComponent(box.isSnapped ? 0.18 : 0.1).setFill()
        box.rect.fill()
        strokeOutlined(NSBezierPath(rect: box.rect))
    }

    private static func appendSegment(_ segment: Segment, to path: NSBezierPath) {
        path.move(to: segment.start)
        path.line(to: segment.end)
        let half = capLength / 2
        for point in [segment.start, segment.end] {
            if segment.isHorizontal {
                path.move(to: CGPoint(x: point.x, y: point.y - half))
                path.line(to: CGPoint(x: point.x, y: point.y + half))
            } else {
                path.move(to: CGPoint(x: point.x - half, y: point.y))
                path.line(to: CGPoint(x: point.x + half, y: point.y))
            }
        }
    }

    /// 1px accent line on top of a dark outline so it stays visible on any background.
    private static func strokeOutlined(_ path: NSBezierPath) {
        path.lineCapStyle = .square
        outline.setStroke()
        path.lineWidth = outlineWidth
        path.stroke()
        accent.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

/// Where each label pill of a scene goes, in window-local points.
@MainActor
enum MeasureLabelLayout {
    enum Alignment {
        case above
        case below
        case right
        case badge
    }

    /// One label: its text, the point it hangs off and how it hangs.
    struct Placement {
        let text: String
        let anchor: CGPoint
        let alignment: Alignment
    }

    private static let labelGap: CGFloat = 6
    private static let edgeInset: CGFloat = 4
    private static let badgeOffset = CGPoint(x: 14, y: 14)

    /// Hover horizontal, hover vertical, box and badge labels (nil when absent), in that order.
    static func placements(for scene: MeasureScene) -> [Placement?] {
        let hover = scene.hover.map { hover in
            (
                Placement(
                    text: hover.horizontalLabel,
                    anchor: CGPoint(x: hover.horizontal.midpoint.x, y: hover.horizontal.start.y + labelGap),
                    alignment: .above
                ),
                Placement(
                    text: hover.verticalLabel,
                    anchor: CGPoint(x: hover.vertical.start.x + labelGap, y: hover.vertical.midpoint.y),
                    alignment: .right
                )
            )
        }
        let box = scene.box.map {
            Placement(text: $0.label, anchor: CGPoint(x: $0.rect.midX, y: $0.rect.minY - labelGap), alignment: .below)
        }
        let badge = scene.badge.map { Placement(text: $0.text, anchor: $0.anchor, alignment: .badge) }
        return [hover?.0, hover?.1, box, badge]
    }

    /// Frame origin for a pill of `size` placed as described, kept inside `bounds`.
    static func origin(for placement: Placement, size: CGSize, in bounds: CGRect) -> CGPoint {
        let anchor = placement.anchor
        let origin = switch placement.alignment {
        case .above: CGPoint(x: anchor.x - size.width / 2, y: anchor.y)
        case .below: CGPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height)
        case .right: CGPoint(x: anchor.x, y: anchor.y - size.height / 2)
        case .badge: CGPoint(x: anchor.x + badgeOffset.x, y: anchor.y + badgeOffset.y)
        }
        let area = bounds.insetBy(dx: edgeInset, dy: edgeInset)
        let x = min(max(origin.x, area.minX), max(area.maxX - size.width, area.minX))
        let y = min(max(origin.y, area.minY), max(area.maxY - size.height, area.minY))
        return CGPoint(x: x.rounded(), y: y.rounded())
    }
}
