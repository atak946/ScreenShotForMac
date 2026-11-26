import AppKit
import CoreGraphics

extension AnnotationRenderer {
    /// Dims the whole canvas except the holes of every visible spotlight annotation.
    func drawSpotlight(_ document: EditorDocument, hiddenIDs: Set<UUID>, in context: CGContext) {
        let spots = document.annotations.filter { $0.kind == .spotlight && !hiddenIDs.contains($0.id) }
        guard !spots.isEmpty else { return }
        context.saveGState()
        context.addRect(document.canvasRect.insetBy(dx: -1, dy: -1))
        for spot in spots {
            let rect = spot.rect
            let radius = min(spot.style.cornerRadius, rect.width / 2, rect.height / 2)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        }
        context.setFillColor(CGColor(gray: 0, alpha: document.spotlightOpacity))
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    func drawMagnifier(_ annotation: Annotation, source image: EffectSource, in context: CGContext) {
        let style = annotation.style
        let sourceRadius = annotation.sourceRadius
        guard sourceRadius > 1 else { return }
        let source = CGPoint(x: annotation.rect.midX, y: annotation.rect.midY)
        let callout = annotation.callout
        let calloutRadius = annotation.calloutRadius
        let color = style.color.cgColor(opacity: style.opacity)
        let border = max(style.lineWidth / 2, 1.5)

        // Connector between the two circles.
        let direction = (callout - source).normalized
        if source.distance(to: callout) > sourceRadius + calloutRadius {
            context.setStrokeColor(color)
            context.setLineWidth(border)
            context.move(to: source + direction * sourceRadius)
            context.addLine(to: callout - direction * calloutRadius)
            context.strokePath()
        }
        context.setStrokeColor(color)
        context.setLineWidth(border)
        context.strokeEllipse(in: circleRect(center: source, radius: sourceRadius))

        let calloutRect = circleRect(center: callout, radius: calloutRadius)
        context.saveGState()
        applyShadow(in: context)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fillEllipse(in: calloutRect)
        context.restoreGState()

        context.saveGState()
        context.addEllipse(in: calloutRect)
        context.clip()
        context.translateBy(x: callout.x, y: callout.y)
        context.scaleBy(x: Annotation.magnification, y: Annotation.magnification)
        context.translateBy(x: -source.x, y: -source.y)
        if let cgImage = image.image { drawImage(cgImage, in: image.rect, context: context) }
        context.restoreGState()

        context.setStrokeColor(color)
        context.setLineWidth(style.lineWidth)
        context.strokeEllipse(in: calloutRect.insetBy(dx: style.lineWidth / 2, dy: style.lineWidth / 2))
    }

    func drawCounter(_ annotation: Annotation, in context: CGContext) {
        let style = annotation.style
        let radius = TextLayout.counterRadius(for: style)
        context.saveGState()
        applyShadow(in: context)
        context.setFillColor(style.color.cgColor(opacity: style.opacity))
        context.fillEllipse(in: circleRect(center: annotation.start, radius: radius))
        context.restoreGState()

        let label = NSAttributedString(string: "\(annotation.number)", attributes: [
            .font: NSFont.systemFont(ofSize: radius * 1.1, weight: .bold),
            .foregroundColor: style.color.isLight ? NSColor.black : NSColor.white,
        ])
        let size = label.size()
        let origin = CGPoint(x: annotation.start.x - size.width / 2, y: annotation.start.y - size.height / 2)
        drawAttributed(label, at: origin, in: context)
    }

    func drawText(_ annotation: Annotation, in context: CGContext) {
        guard !annotation.text.isEmpty else { return }
        let style = annotation.style
        if style.filled {
            let bubble = TextLayout.frame(for: annotation)
            context.setFillColor(style.color.cgColor(opacity: style.opacity))
            context.addPath(CGPath(roundedRect: bubble, cornerWidth: 6, cornerHeight: 6, transform: nil))
            context.fillPath()
        } else {
            context.setShadow(offset: .zero, blur: 2, color: CGColor(gray: style.color.isLight ? 0 : 1, alpha: 0.6))
        }
        drawAttributed(TextLayout.attributedString(for: annotation), at: annotation.start, in: context)
    }

    private func circleRect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
