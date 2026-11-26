import CoreGraphics
import Foundation

/// Immutable editor state snapshot. All mutations return a new value.
/// `@unchecked Sendable`: `CGImage` is immutable.
struct EditorDocument: Equatable, @unchecked Sendable {
    static let paddingOptions: [CGFloat] = [0, 20, 50, 100]
    static let spotlightOpacities: [CGFloat] = [0.3, 0.5, 0.7, 0.85]

    let baseImage: CGImage
    /// Pixels per point of `baseImage`.
    let scale: CGFloat
    var annotations: [Annotation]
    /// Crop in document coordinates (points); nil means the full canvas.
    var cropRect: CGRect?
    /// Extra canvas around the image on every side (points).
    var canvasPadding: CGFloat
    /// Fill of the padding area; nil = transparent.
    var backgroundColor: AnnotationColor?
    /// Dim strength of spotlight annotations (shared by all of them).
    var spotlightOpacity: CGFloat

    init(
        baseImage: CGImage,
        scale: CGFloat,
        annotations: [Annotation] = [],
        cropRect: CGRect? = nil,
        canvasPadding: CGFloat = 0,
        backgroundColor: AnnotationColor? = .white,
        spotlightOpacity: CGFloat = 0.6
    ) {
        self.baseImage = baseImage
        self.scale = max(scale, 0.1)
        self.annotations = annotations
        self.cropRect = cropRect
        self.canvasPadding = canvasPadding
        self.backgroundColor = backgroundColor
        self.spotlightOpacity = spotlightOpacity
    }

    /// Image bounds in points.
    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: CGFloat(baseImage.width) / scale, height: CGFloat(baseImage.height) / scale)
    }

    /// Image bounds plus padding.
    var canvasRect: CGRect { bounds.insetBy(dx: -canvasPadding, dy: -canvasPadding) }

    /// The part of the canvas that is exported.
    var outputRect: CGRect { (cropRect ?? canvasRect).intersection(canvasRect) }

    var nextCounterNumber: Int {
        (annotations.filter { $0.kind == .counter }.map(\.number).max() ?? 0) + 1
    }

    func annotation(id: UUID?) -> Annotation? {
        guard let id else { return nil }
        return annotations.first { $0.id == id }
    }

    func adding(_ annotation: Annotation) -> EditorDocument {
        var copy = self
        copy.annotations = annotations + [annotation]
        return copy
    }

    func replacing(_ annotation: Annotation) -> EditorDocument {
        var copy = self
        copy.annotations = annotations.map { $0.id == annotation.id ? annotation : $0 }
        return copy
    }

    func removing(id: UUID) -> EditorDocument {
        var copy = self
        copy.annotations = annotations.filter { $0.id != id }
        return copy
    }

    func removing(ids: Set<UUID>) -> EditorDocument {
        var copy = self
        copy.annotations = annotations.filter { !ids.contains($0.id) }
        return copy
    }

    func adding(_ newAnnotations: [Annotation]) -> EditorDocument {
        var copy = self
        copy.annotations = annotations + newAnnotations
        return copy
    }

    func moving(ids: Set<UUID>, by delta: CGPoint) -> EditorDocument {
        var copy = self
        copy.annotations = annotations.map { ids.contains($0.id) ? $0.moved(by: delta) : $0 }
        return copy
    }

    func withCrop(_ rect: CGRect?) -> EditorDocument {
        var copy = self
        copy.cropRect = rect
        return copy
    }

    /// Changing the padding drops a crop that no longer matches the canvas.
    func withPadding(_ padding: CGFloat) -> EditorDocument {
        var copy = self
        copy.canvasPadding = max(padding, 0)
        copy.cropRect = cropRect.map { $0.intersection(copy.canvasRect) }.flatMap { $0.isEmpty ? nil : $0 }
        return copy
    }

    func withBackground(_ color: AnnotationColor?) -> EditorDocument {
        var copy = self
        copy.backgroundColor = color
        return copy
    }

    func withSpotlightOpacity(_ opacity: CGFloat) -> EditorDocument {
        var copy = self
        copy.spotlightOpacity = min(max(opacity, 0), 1)
        return copy
    }

    /// New document with a different base image, keeping the rest.
    func withBaseImage(_ image: CGImage, annotations: [Annotation], cropRect: CGRect?) -> EditorDocument {
        EditorDocument(
            baseImage: image, scale: scale, annotations: annotations, cropRect: cropRect,
            canvasPadding: canvasPadding, backgroundColor: backgroundColor, spotlightOpacity: spotlightOpacity
        )
    }

    static func == (lhs: EditorDocument, rhs: EditorDocument) -> Bool {
        lhs.baseImage === rhs.baseImage
            && lhs.scale == rhs.scale
            && lhs.annotations == rhs.annotations
            && lhs.cropRect == rhs.cropRect
            && lhs.canvasPadding == rhs.canvasPadding
            && lhs.backgroundColor == rhs.backgroundColor
            && lhs.spotlightOpacity == rhs.spotlightOpacity
    }
}
