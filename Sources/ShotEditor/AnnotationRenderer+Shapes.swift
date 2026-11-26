import AppKit
import CoreGraphics

extension AnnotationRenderer {
    func drawArrow(_ annotation: Annotation, in context: CGContext) {
        let style = annotation.style
        applyStroke(style, in: context)
        applyShadow(in: context)
        guard style.dashed || style.doubleHeaded else {
            guard let path = ArrowPath.tapered(from: annotation.start, to: annotation.end, lineWidth: style.lineWidth)
            else { return }
            context.addPath(path)
            context.fillPath()
            return
        }
        drawStyledArrow(annotation, in: context)
    }

    /// Constant-width (optionally dashed) shaft with one or two filled heads.
    private func drawStyledArrow(_ annotation: Annotation, in context: CGContext) {
        let style = annotation.style
        let length = annotation.start.distance(to: annotation.end)
        guard length > 1 else { return }
        let direction = (annotation.end - annotation.start).normalized
        let headLength = ArrowPath.headLength(lineWidth: style.lineWidth, segmentLength: length, heads: style.doubleHeaded ? 2 : 1)
        let shaftEnd = annotation.end - direction * (headLength * 0.8)
        let shaftStart = style.doubleHeaded ? annotation.start + direction * (headLength * 0.8) : annotation.start

        context.saveGState()
        applyDash(style, in: context)
        context.move(to: shaftStart)
        context.addLine(to: shaftEnd)
        context.strokePath()
        context.restoreGState()

        context.addPath(ArrowPath.head(tip: annotation.end, direction: direction, length: headLength))
        if style.doubleHeaded {
            context.addPath(ArrowPath.head(tip: annotation.start, direction: direction * -1, length: headLength))
        }
        context.fillPath()
    }

    func drawLine(_ annotation: Annotation, in context: CGContext) {
        applyStroke(annotation.style, in: context)
        applyDash(annotation.style, in: context)
        applyShadow(in: context)
        context.move(to: annotation.start)
        context.addLine(to: annotation.end)
        context.strokePath()
    }

    func drawRectangle(_ annotation: Annotation, in context: CGContext) {
        let style = annotation.style
        applyStroke(style, in: context)
        if !style.filled { applyDash(style, in: context) }
        let rect = style.filled ? annotation.rect : annotation.rect.insetBy(dx: style.lineWidth / 2, dy: style.lineWidth / 2)
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(style.cornerRadius, rect.width / 2, rect.height / 2)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.drawPath(using: style.filled ? .fill : .stroke)
    }

    func drawEllipse(_ annotation: Annotation, in context: CGContext) {
        let style = annotation.style
        applyStroke(style, in: context)
        if !style.filled { applyDash(style, in: context) }
        let rect = style.filled ? annotation.rect : annotation.rect.insetBy(dx: style.lineWidth / 2, dy: style.lineWidth / 2)
        guard rect.width > 0, rect.height > 0 else { return }
        context.addEllipse(in: rect)
        context.drawPath(using: style.filled ? .fill : .stroke)
    }

    func drawHighlight(_ annotation: Annotation, in context: CGContext) {
        context.setBlendMode(.multiply)
        context.setFillColor(annotation.style.color.cgColor(opacity: 0.55 * annotation.style.opacity))
        context.fill(annotation.rect)
    }

    func drawFill(_ annotation: Annotation, in context: CGContext) {
        context.setFillColor(annotation.style.color.cgColor())
        context.fill(annotation.rect)
    }

    func drawEffect(_ source: EffectSource, annotation: Annotation, in context: CGContext) {
        let rect = annotation.rect.intersection(source.rect)
        guard let image = source.image, !rect.isNull, rect.width > 0, rect.height > 0 else { return }
        context.clip(to: rect)
        drawImage(image, in: source.rect, context: context)
    }

    func drawPen(_ annotation: Annotation, in context: CGContext) {
        guard let first = annotation.points.first else { return }
        applyStroke(annotation.style, in: context)
        applyDash(annotation.style, in: context)
        context.addPath(PenPath.smoothed(points: annotation.points, start: first))
        context.strokePath()
    }

    func drawEmbeddedImage(_ annotation: Annotation, in context: CGContext) {
        guard let image = annotation.image?.cgImage, annotation.rect.width > 0, annotation.rect.height > 0 else { return }
        applyShadow(in: context)
        context.setAlpha(annotation.style.opacity)
        drawImage(image, in: annotation.rect, context: context)
    }
}
