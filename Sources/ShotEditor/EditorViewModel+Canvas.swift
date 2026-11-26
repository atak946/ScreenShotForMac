import AppKit
import ShotCore

/// Canvas-level edits: padding, background, rotation, stamps, smart erase.
extension EditorViewModel {
    static let stamps = ["✅", "❌", "⚠️", "⭐️", "👉", "❓"]
    private static let stampFontSize: CGFloat = 48

    func setPadding(_ padding: CGFloat) {
        apply(String(localized: "Canvas Padding", bundle: .module)) { $0.withPadding(padding) }
    }

    func setBackground(_ color: AnnotationColor?) {
        apply(String(localized: "Canvas Background", bundle: .module)) { $0.withBackground(color) }
    }

    func setSpotlightOpacity(_ opacity: CGFloat) {
        apply(String(localized: "Spotlight Opacity", bundle: .module)) { $0.withSpotlightOpacity(opacity) }
    }

    func transform(_ transform: DocumentTransform) {
        cancelPendingModes()
        guard let transformed = document.transformed(transform) else {
            NSSound.beep()
            return
        }
        apply(transform.actionName) { _ in transformed }
    }

    /// Inserts an emoji stamp centered in the visible region.
    func insertStamp(_ emoji: String) {
        var stampStyle = style
        stampStyle.fontSize = Self.stampFontSize
        stampStyle.filled = false
        stampStyle.opacity = 1
        let probe = Annotation(kind: .text, start: .zero, text: emoji, style: stampStyle)
        let size = TextLayout.textFrame(for: probe).size
        let center = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        let stamp = Annotation(
            kind: .text, start: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
            text: emoji, style: stampStyle
        )
        if tool == .crop { selectTool(.select) }
        apply(String(localized: "Add Stamp", bundle: .module)) { $0.adding(stamp) }
        selectedID = stamp.id
    }

    /// Smart eraser: fills the rect with the dominant color of the base image along its border.
    func sampledFill(_ annotation: Annotation) -> Annotation {
        guard annotation.kind == .fill else { return annotation }
        let scale = document.scale
        let pixelRect = CGRect(
            x: annotation.rect.minX * scale, y: annotation.rect.minY * scale,
            width: annotation.rect.width * scale, height: annotation.rect.height * scale
        )
        guard let color = ImageSampler.dominantBorderColor(in: document.baseImage, pixelRect: pixelRect) else {
            Log.editor.debug("Smart erase outside the image; keeping previous fill color")
            return annotation
        }
        var style = annotation.style
        style.color = color
        return annotation.with(style: style)
    }

    private func cancelPendingModes() {
        if tool == .crop { selectTool(.select) }
    }
}
