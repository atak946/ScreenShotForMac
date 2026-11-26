import CoreGraphics
import Foundation

enum AnnotationKind: String, CaseIterable, Sendable {
    case arrow, line, rectangle, ellipse, text, highlight, blur, pixelate, counter, pen
    case spotlight, magnifier, fill, image

    /// Kinds whose geometry is the rect spanned by `start` and `end`.
    var isRectBased: Bool {
        switch self {
        case .rectangle, .ellipse, .highlight, .blur, .pixelate, .spotlight, .magnifier, .fill, .image: return true
        default: return false
        }
    }

    var isSegment: Bool { self == .arrow || self == .line }

    var displayName: String {
        switch self {
        case .arrow: return String(localized: "Arrow", bundle: .module)
        case .line: return String(localized: "Line", bundle: .module)
        case .rectangle: return String(localized: "Rectangle", bundle: .module)
        case .ellipse: return String(localized: "Ellipse", bundle: .module)
        case .text: return String(localized: "Text", bundle: .module)
        case .highlight: return String(localized: "Highlight", bundle: .module)
        case .blur: return String(localized: "Blur", bundle: .module)
        case .pixelate: return String(localized: "Pixelate", bundle: .module)
        case .counter: return String(localized: "Counter", bundle: .module)
        case .pen: return String(localized: "Pen", bundle: .module)
        case .spotlight: return String(localized: "Spotlight", bundle: .module)
        case .magnifier: return String(localized: "Magnifier", bundle: .module)
        case .fill: return String(localized: "Erase", bundle: .module)
        case .image: return String(localized: "Image", bundle: .module)
        }
    }
}

/// A single vector annotation in document coordinates (image points, top-left origin).
struct Annotation: Identifiable, Equatable, Sendable {
    /// Magnifier callout radius relative to the source radius (2x zoom).
    static let magnification: CGFloat = 2

    let id: UUID
    let kind: AnnotationKind
    /// Segment start / rect corner / text origin / counter center.
    var start: CGPoint
    /// Segment end / opposite rect corner.
    var end: CGPoint
    /// Freehand pen points.
    var points: [CGPoint]
    var text: String
    /// Step number for counters.
    var number: Int
    var style: AnnotationStyle
    /// Magnifier callout center.
    var callout: CGPoint
    /// Embedded bitmap for `.image` annotations.
    var image: AnnotationImage?

    init(
        id: UUID = UUID(),
        kind: AnnotationKind,
        start: CGPoint,
        end: CGPoint? = nil,
        points: [CGPoint] = [],
        text: String = "",
        number: Int = 0,
        style: AnnotationStyle,
        callout: CGPoint = .zero,
        image: AnnotationImage? = nil
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end ?? start
        self.points = points
        self.text = text
        self.number = number
        self.style = style
        self.callout = callout
        self.image = image
    }

    var rect: CGRect { Geometry.rect(from: start, to: end) }

    /// Magnifier source circle radius.
    var sourceRadius: CGFloat { min(rect.width, rect.height) / 2 }
    var calloutRadius: CGFloat { sourceRadius * Self.magnification }

    /// Copy with a fresh identity, e.g. for paste.
    func duplicated(offset: CGPoint) -> Annotation {
        Annotation(
            kind: kind, start: start + offset, end: end + offset, points: points.map { $0 + offset },
            text: text, number: number, style: style, callout: callout + offset, image: image
        )
    }

    func moved(by delta: CGPoint) -> Annotation {
        var copy = self
        copy.start = start + delta
        copy.end = end + delta
        copy.points = points.map { $0 + delta }
        copy.callout = callout + delta
        return copy
    }

    func movedCallout(by delta: CGPoint) -> Annotation {
        var copy = self
        copy.callout = callout + delta
        return copy
    }

    func movedSource(by delta: CGPoint) -> Annotation {
        var copy = self
        copy.start = start + delta
        copy.end = end + delta
        return copy
    }

    func with(start: CGPoint? = nil, end: CGPoint? = nil) -> Annotation {
        var copy = self
        copy.start = start ?? self.start
        copy.end = end ?? self.end
        return copy
    }

    func with(points: [CGPoint]) -> Annotation {
        var copy = self
        copy.points = points
        return copy
    }

    func with(callout: CGPoint) -> Annotation {
        var copy = self
        copy.callout = callout
        return copy
    }

    /// Places the magnifier callout diagonally up-right of the source.
    func withDefaultCallout() -> Annotation {
        let offset = (sourceRadius + calloutRadius) * 0.9 + 12
        return with(callout: CGPoint(x: rect.midX + offset, y: rect.midY - offset))
    }

    func appending(point: CGPoint) -> Annotation {
        var copy = self
        copy.points = points + [point]
        copy.end = point
        return copy
    }

    func with(text: String) -> Annotation {
        var copy = self
        copy.text = text
        return copy
    }

    func with(style: AnnotationStyle) -> Annotation {
        var copy = self
        copy.style = style
        return copy
    }
}
