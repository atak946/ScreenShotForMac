import CoreGraphics
import Foundation

/// One input image for the combine renderer: pixels plus the backing scale they were captured at.
/// `CGImage` is immutable, so sharing it between threads is safe.
public struct CombineImage: @unchecked Sendable {
    public let image: CGImage
    public let scale: CGFloat

    public init(image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = max(scale, 0.01)
    }

    /// Size in points (pixels divided by scale).
    public var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}

/// How the images are arranged on the canvas.
public enum CombineArrangement: String, Sendable, CaseIterable, Identifiable, Codable {
    case vertical
    case horizontal
    case grid

    public var id: String { rawValue }
}

/// Cross-axis alignment of images that are smaller than their row / column.
public enum CombineAlignment: String, Sendable, CaseIterable, Identifiable, Codable {
    case start
    case center
    case end

    public var id: String { rawValue }

    /// Offset of an item of `length` inside `available` space.
    func offset(for length: CGFloat, in available: CGFloat) -> CGFloat {
        let slack = max(0, available - length)
        switch self {
        case .start: return 0
        case .center: return slack / 2
        case .end: return slack
        }
    }
}

/// sRGB color with alpha, value type so it can be compared and sent across actors.
public struct CombineColor: Sendable, Equatable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = CombineColor(red: 1, green: 1, blue: 1)

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

/// All user-adjustable parameters of a combined image. Lengths are in points.
public struct CombineLayout: Sendable, Equatable, Codable {
    public static let spacingRange: ClosedRange<Double> = 0...120
    public static let paddingRange: ClosedRange<Double> = 0...200
    public static let cornerRadiusRange: ClosedRange<Double> = 0...48
    public static let columnsRange: ClosedRange<Int> = 1...12
    /// "Match sizes" never enlarges an image beyond this factor.
    public static let maxMatchUpscale: CGFloat = 2

    public var arrangement: CombineArrangement
    public var columns: Int
    public var spacing: Double
    public var padding: Double
    public var fillsBackground: Bool
    public var backgroundColor: CombineColor
    public var alignment: CombineAlignment
    public var cornerRadius: Double
    public var matchSizes: Bool

    public init(
        arrangement: CombineArrangement = .vertical,
        columns: Int = 2,
        spacing: Double = 16,
        padding: Double = 24,
        fillsBackground: Bool = true,
        backgroundColor: CombineColor = .white,
        alignment: CombineAlignment = .center,
        cornerRadius: Double = 0,
        matchSizes: Bool = false
    ) {
        self.arrangement = arrangement
        self.columns = columns
        self.spacing = spacing
        self.padding = padding
        self.fillsBackground = fillsBackground
        self.backgroundColor = backgroundColor
        self.alignment = alignment
        self.cornerRadius = cornerRadius
        self.matchSizes = matchSizes
    }

    public static let standard = CombineLayout()

    /// Copy with every value clamped to its valid range.
    public func sanitized() -> CombineLayout {
        var copy = self
        copy.columns = min(max(columns, Self.columnsRange.lowerBound), Self.columnsRange.upperBound)
        copy.spacing = spacing.clamped(to: Self.spacingRange)
        copy.padding = padding.clamped(to: Self.paddingRange)
        copy.cornerRadius = cornerRadius.clamped(to: Self.cornerRadiusRange)
        return copy
    }
}

/// Direction of the slices produced by Split.
public enum SplitAxis: String, Sendable, CaseIterable, Identifiable, Codable {
    /// Horizontal cut lines: slices stacked top to bottom.
    case horizontal
    /// Vertical cut lines: slices placed left to right.
    case vertical

    public var id: String { rawValue }
}

/// How cut positions are determined.
public enum SplitMethod: String, Sendable, CaseIterable, Identifiable, Codable {
    case equal
    case custom

    public var id: String { rawValue }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
