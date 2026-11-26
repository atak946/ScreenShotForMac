import CoreGraphics
import Foundation
import ShotCore

/// Where an effect annotation sits in the z-order while rendering.
struct LayerPosition {
    let index: Int
    let hiddenIDs: Set<UUID>
}

/// Image an effect samples from, placed at `rect` (document points).
struct EffectSource {
    let image: CGImage?
    let rect: CGRect
}

extension AnnotationKind {
    /// Effects that sample what is beneath them.
    var isLayeredEffect: Bool { self == .blur || self == .pixelate || self == .magnifier }
}

/// Caches effect images rendered from "base image + annotations beneath" for small regions.
/// Only annotations that overlap the region are composited, and only the region (plus a blur
/// margin) is rendered, so moving the effect itself or unrelated annotations costs nothing.
@MainActor
final class LayeredEffectCache {
    private static let limit = 12

    struct Key: Equatable {
        let kind: AnnotationKind
        let region: CGRect
        /// Base image, canvas settings and the overlapping annotations beneath.
        let composite: EditorDocument
    }

    private var entries: [(key: Key, image: CGImage?)] = []

    func image(for key: Key, make: () -> CGImage?) -> CGImage? {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.image
        }
        let image = make()
        if entries.count >= Self.limit { entries.removeFirst() }
        entries.append((key, image))
        return image
    }
}

extension AnnotationRenderer {
    /// Blur reaches ~3 sigma; render that much context around the region.
    private static let blurMarginFactor: CGFloat = 3
    private static let magnifierMargin: CGFloat = 1

    /// Effect image including the annotations beneath `annotation`; nil when nothing
    /// beneath overlaps it (callers then use the cached full-image effect).
    func layeredSource(for annotation: Annotation, document: EditorDocument, position: LayerPosition) -> EffectSource? {
        let margin = annotation.kind == .blur ? ImageEffects.blurRadiusPoints * Self.blurMarginFactor : Self.magnifierMargin
        let target = annotation.rect.intersection(document.canvasRect)
        guard !target.isNull, target.width > 0, target.height > 0 else { return nil }
        let region = pixelAligned(target.insetBy(dx: -margin, dy: -margin).intersection(document.canvasRect), scale: document.scale)
        let beneath = document.annotations.prefix(position.index).filter { other in
            other.kind != .spotlight && !position.hiddenIDs.contains(other.id)
                && HitTesting.bounds(of: other).intersects(region)
        }
        guard !beneath.isEmpty else { return nil }
        var composite = document
        composite.annotations = beneath
        let key = LayeredEffectCache.Key(kind: annotation.kind, region: region, composite: composite)
        let image = layers.image(for: key) { makeEffectImage(kind: annotation.kind, composite: composite, region: region) }
        return EffectSource(image: image, rect: region)
    }

    private func makeEffectImage(kind: AnnotationKind, composite: EditorDocument, region: CGRect) -> CGImage? {
        guard let rendered = render(composite, region: region) else { return nil }
        switch kind {
        case .blur:
            return effects.makeBlur(rendered)
        case .pixelate:
            // Core Image space is y-up with its origin at the region's bottom-left corner.
            let scale = composite.scale
            let origin = CGPoint(x: -region.minX * scale, y: (region.maxY - composite.bounds.maxY) * scale)
            return effects.makePixelate(rendered, gridOrigin: origin)
        default:
            return rendered
        }
    }

    /// Renders `region` of `document` at pixel resolution.
    private func render(_ document: EditorDocument, region: CGRect) -> CGImage? {
        let width = Int((region.width * document.scale).rounded())
        let height = Int((region.height * document.scale).rounded())
        let space = document.baseImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard width > 0, height > 0, let space,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            Log.editor.error("Layered effect: could not create \(width)x\(height) context")
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: document.scale, y: -document.scale)
        context.translateBy(x: -region.minX, y: -region.minY)
        draw(document, in: context)
        return context.makeImage()
    }

    /// Snaps a rect to whole pixels so region renders line up with the base image.
    private func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
        return CGRect(x: pixels.minX / scale, y: pixels.minY / scale, width: pixels.width / scale, height: pixels.height / scale)
    }
}
