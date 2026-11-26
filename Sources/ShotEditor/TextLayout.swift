import AppKit

/// Shared text metrics so rendering, hit testing and the inline editor agree.
@MainActor
enum TextLayout {
    static let bubblePadding: CGFloat = 6

    static func font(size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: max(size, 4), weight: .semibold)
    }

    static func textColor(for style: AnnotationStyle) -> NSColor {
        guard style.filled else { return style.color.nsColor }
        return style.color.isLight ? NSColor.black : NSColor.white
    }

    static func attributedString(for annotation: Annotation) -> NSAttributedString {
        let text = annotation.text.isEmpty ? " " : annotation.text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(size: annotation.style.fontSize),
            .foregroundColor: textColor(for: annotation.style).withAlphaComponent(annotation.style.opacity),
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    /// Text glyph frame (without bubble padding), origin = annotation.start.
    static func textFrame(for annotation: Annotation) -> CGRect {
        let size = attributedString(for: annotation).size()
        return CGRect(origin: annotation.start, size: CGSize(width: ceil(size.width), height: ceil(size.height)))
    }

    /// Full visual frame including the bubble padding.
    static func frame(for annotation: Annotation) -> CGRect {
        textFrame(for: annotation).insetBy(dx: -bubblePadding, dy: -bubblePadding / 2)
    }

    static let counterRadiusFactor: CGFloat = 0.75

    static func counterRadius(for style: AnnotationStyle) -> CGFloat {
        max(style.fontSize * counterRadiusFactor, 8)
    }
}
