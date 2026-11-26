import CoreGraphics

struct AnnotationStyle: Equatable, Sendable {
    var color: AnnotationColor
    var lineWidth: CGFloat
    var filled: Bool
    var fontSize: CGFloat
    var opacity: CGFloat
    var dashed: Bool
    /// Arrow head on both ends.
    var doubleHeaded: Bool
    var cornerRadius: CGFloat

    static let `default` = AnnotationStyle(
        color: .red, lineWidth: 4, filled: false, fontSize: 22, opacity: 1,
        dashed: false, doubleHeaded: false, cornerRadius: 4
    )

    /// Thin / medium / thick presets.
    static let lineWidths: [CGFloat] = [2, 4, 8]
    static let fontSizes: [CGFloat] = [14, 18, 22, 28, 36, 48, 64]
    static let cornerRadii: [CGFloat] = [0, 4, 8, 16, 32]
    static let fontSizeRange: ClosedRange<CGFloat> = 6...400
}

/// Wraps an embedded image; equality is identity because `CGImage` is immutable.
struct AnnotationImage: Equatable, @unchecked Sendable {
    let cgImage: CGImage

    static func == (lhs: AnnotationImage, rhs: AnnotationImage) -> Bool {
        lhs.cgImage === rhs.cgImage
    }
}
