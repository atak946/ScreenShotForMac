import AppKit
import CoreGraphics
import ShotCore

/// Draws an `EditorDocument` into a CGContext whose user space is document
/// coordinates (points, top-left origin, y pointing down).
/// Used by the on-screen canvas and by `flatten()`.
@MainActor
struct AnnotationRenderer {
    let effects: ImageEffects
    /// Effect images that include the annotations beneath blur / pixelate / magnifier.
    let layers = LayeredEffectCache()

    /// - Parameter nearestNeighbor: crisp pixels when zoomed in on screen.
    func draw(_ document: EditorDocument, in context: CGContext, hiddenIDs: Set<UUID> = [], nearestNeighbor: Bool = false) {
        context.saveGState()
        if let background = document.backgroundColor, document.canvasPadding > 0 {
            context.setFillColor(background.cgColor())
            context.fill(document.canvasRect)
        }
        context.interpolationQuality = nearestNeighbor ? .none : .high
        drawImage(document.baseImage, in: document.bounds, context: context)
        context.interpolationQuality = .high

        var didDrawSpotlight = false
        for (index, annotation) in document.annotations.enumerated() where !hiddenIDs.contains(annotation.id) {
            if annotation.kind == .spotlight {
                if !didDrawSpotlight { drawSpotlight(document, hiddenIDs: hiddenIDs, in: context) }
                didDrawSpotlight = true
                continue
            }
            let layer = annotation.kind.isLayeredEffect ? LayerPosition(index: index, hiddenIDs: hiddenIDs) : nil
            draw(annotation, document: document, layer: layer, in: context)
        }
        context.restoreGState()
    }

    /// Renders the document at full pixel resolution, respecting crop and padding.
    func flatten(_ document: EditorDocument) -> CGImage? {
        let output = document.outputRect
        let width = Int((output.width * document.scale).rounded())
        let height = Int((output.height * document.scale).rounded())
        guard width > 0, height > 0 else {
            Log.editor.error("Flatten failed: empty output rect")
            return nil
        }
        guard let context = makeBitmapContext(width: width, height: height, preferred: document.baseImage.colorSpace) else {
            Log.editor.error("Flatten failed: could not create bitmap context")
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: document.scale, y: -document.scale)
        context.translateBy(x: -output.minX, y: -output.minY)
        draw(document, in: context)
        return context.makeImage()
    }

    /// Tries the source color space first, falling back to sRGB for unsupported spaces.
    private func makeBitmapContext(width: Int, height: Int, preferred: CGColorSpace?) -> CGContext? {
        let candidates = [preferred, CGColorSpace(name: CGColorSpace.sRGB)].compactMap(\.self)
        for space in candidates {
            if let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                return context
            }
        }
        return nil
    }

    // MARK: - Dispatch

    func draw(_ annotation: Annotation, document: EditorDocument, layer: LayerPosition? = nil, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let source = layer.flatMap { layeredSource(for: annotation, document: document, position: $0) }
        switch annotation.kind {
        case .arrow: drawArrow(annotation, in: context)
        case .line: drawLine(annotation, in: context)
        case .rectangle: drawRectangle(annotation, in: context)
        case .ellipse: drawEllipse(annotation, in: context)
        case .text: drawText(annotation, in: context)
        case .highlight: drawHighlight(annotation, in: context)
        case .blur:
            let fallback = EffectSource(image: effects.blurred(document.baseImage), rect: document.bounds)
            drawEffect(source ?? fallback, annotation: annotation, in: context)
        case .pixelate:
            let fallback = EffectSource(image: effects.pixelated(document.baseImage), rect: document.bounds)
            drawEffect(source ?? fallback, annotation: annotation, in: context)
        case .counter: drawCounter(annotation, in: context)
        case .pen: drawPen(annotation, in: context)
        case .spotlight: drawSpotlight(document, hiddenIDs: [], in: context)
        case .magnifier:
            let fallback = EffectSource(image: document.baseImage, rect: document.bounds)
            drawMagnifier(annotation, source: source ?? fallback, in: context)
        case .fill: drawFill(annotation, in: context)
        case .image: drawEmbeddedImage(annotation, in: context)
        }
    }

    // MARK: - Primitives

    func applyStroke(_ style: AnnotationStyle, in context: CGContext) {
        context.setStrokeColor(style.color.cgColor(opacity: style.opacity))
        context.setFillColor(style.color.cgColor(opacity: style.opacity))
        context.setLineWidth(style.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    func applyDash(_ style: AnnotationStyle, in context: CGContext) {
        guard style.dashed else { return }
        context.setLineDash(phase: 0, lengths: [style.lineWidth * 1.5, style.lineWidth * 2.5])
    }

    func applyShadow(in context: CGContext) {
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: CGColor(gray: 0, alpha: 0.35))
    }

    func drawAttributed(_ string: NSAttributedString, at point: CGPoint, in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        string.draw(at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Draws an image upright inside `rect` of a y-down context.
    func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}
