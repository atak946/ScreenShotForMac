import AppKit
import CoreGraphics

/// Sendable, equatable RGBA color (sRGB).
struct AnnotationColor: Equatable, Hashable, Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? NSColor.red
        self.init(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: color.alphaComponent)
    }

    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    func cgColor(opacity: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha * opacity)
    }

    /// Perceived luminance, used to pick a readable text color on top of this color.
    var isLight: Bool { (0.299 * red + 0.587 * green + 0.114 * blue) > 0.65 }

    static let red = AnnotationColor(red: 1.0, green: 0.23, blue: 0.19)
    static let orange = AnnotationColor(red: 1.0, green: 0.58, blue: 0.0)
    static let yellow = AnnotationColor(red: 1.0, green: 0.84, blue: 0.04)
    static let green = AnnotationColor(red: 0.20, green: 0.78, blue: 0.35)
    static let blue = AnnotationColor(red: 0.0, green: 0.48, blue: 1.0)
    static let purple = AnnotationColor(red: 0.69, green: 0.32, blue: 0.87)
    static let black = AnnotationColor(red: 0.08, green: 0.08, blue: 0.08)
    static let white = AnnotationColor(red: 1, green: 1, blue: 1)
    static let highlighter = AnnotationColor(red: 1.0, green: 0.90, blue: 0.20)

    /// Curated swatches shown in the style bar and context menu.
    static let palette: [AnnotationColor] = [.red, .orange, .yellow, .green, .blue, .black, .white]
}
