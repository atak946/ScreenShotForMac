import CoreGraphics

/// User zoom / pan state. `zoom == nil` means zoom-to-fit.
struct CanvasViewport: Equatable {
    static let fit = CanvasViewport(zoom: nil, pan: .zero)
    static let zoomRange: ClosedRange<CGFloat> = 0.05...8
    static let steps: [CGFloat] = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5, 6, 8]

    let zoom: CGFloat?
    /// Offset of the image from the centered position, in view points.
    let pan: CGPoint

    static func clampZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }

    static func nextStep(after zoom: CGFloat) -> CGFloat {
        steps.first { $0 > zoom + 0.001 } ?? zoomRange.upperBound
    }

    static func previousStep(before zoom: CGFloat) -> CGFloat {
        steps.last { $0 < zoom - 0.001 } ?? zoomRange.lowerBound
    }
}

/// Maps between document coordinates (points, top-left origin) and canvas view coordinates.
struct CanvasLayout: Equatable {
    /// Breathing room around the image in fit mode.
    static let padding: CGFloat = 32
    /// Extra bottom room so the floating style bar doesn't cover the image in fit mode.
    static let bottomPadding: CGFloat = 60
    /// Zoom-to-fit never upscales beyond 100% to keep screenshots crisp.
    static let maxFitZoom: CGFloat = 1
    /// Above this zoom the image is drawn with nearest-neighbor sampling.
    static let pixelatedZoomThreshold: CGFloat = 2

    let visibleRect: CGRect
    let zoom: CGFloat
    let origin: CGPoint

    init(visibleRect: CGRect, viewBounds: CGRect, viewport: CanvasViewport = .fit) {
        self.visibleRect = visibleRect
        let resolvedZoom = viewport.zoom ?? Self.fitZoom(visibleRect: visibleRect, viewBounds: viewBounds)
        zoom = CanvasViewport.clampZoom(resolvedZoom)
        let size = CGSize(width: visibleRect.width * zoom, height: visibleRect.height * zoom)
        let area = Self.fitArea(in: viewBounds)
        origin = CGPoint(
            x: (area.midX - size.width / 2 + viewport.pan.x).rounded(),
            y: (area.midY - size.height / 2 + viewport.pan.y).rounded()
        )
    }

    static func fitZoom(visibleRect: CGRect, viewBounds: CGRect) -> CGFloat {
        let available = fitArea(in: viewBounds)
        let fit = min(available.width / max(visibleRect.width, 1), available.height / max(visibleRect.height, 1))
        return max(min(fit, maxFitZoom), CanvasViewport.zoomRange.lowerBound)
    }

    /// Region the image is fitted and centered in (view coordinates are flipped: y grows down).
    static func fitArea(in viewBounds: CGRect) -> CGRect {
        CGRect(
            x: viewBounds.minX + padding,
            y: viewBounds.minY + padding,
            width: max(viewBounds.width - padding * 2, 1),
            height: max(viewBounds.height - padding - bottomPadding, 1)
        )
    }

    var usesNearestNeighbor: Bool { zoom > Self.pixelatedZoomThreshold }

    /// Frame of the visible region in view coordinates.
    var imageFrame: CGRect {
        CGRect(origin: origin, size: CGSize(width: visibleRect.width * zoom, height: visibleRect.height * zoom))
    }

    func toView(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + (point.x - visibleRect.minX) * zoom, y: origin.y + (point.y - visibleRect.minY) * zoom)
    }

    func toView(_ rect: CGRect) -> CGRect {
        let topLeft = toView(rect.origin)
        return CGRect(origin: topLeft, size: CGSize(width: rect.width * zoom, height: rect.height * zoom))
    }

    func toDocument(_ point: CGPoint) -> CGPoint {
        CGPoint(x: visibleRect.minX + (point.x - origin.x) / zoom, y: visibleRect.minY + (point.y - origin.y) / zoom)
    }

    /// Converts a tolerance in view points to document points.
    func documentLength(_ viewLength: CGFloat) -> CGFloat { viewLength / zoom }
}
