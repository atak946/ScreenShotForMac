import CoreGraphics
import Foundation

/// sRGB color with alpha, 0...1 components.
public struct RGBAColor: Codable, Equatable, Hashable, Sendable {
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

    /// `0xRRGGBB` hex literal helper.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
}

/// Two-color linear gradient. `angle` follows CSS: 0° = bottom→top, 90° = left→right.
public struct GradientSpec: Codable, Equatable, Hashable, Sendable {
    public var start: RGBAColor
    public var end: RGBAColor
    public var angle: Double

    public init(start: RGBAColor, end: RGBAColor, angle: Double = 135) {
        self.start = start
        self.end = end
        self.angle = angle
    }
}

public enum BackgroundKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case solid
    case gradient
    case wallpaper

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return String(localized: "None", bundle: .module)
        case .solid: return String(localized: "Color", bundle: .module)
        case .gradient: return String(localized: "Gradient", bundle: .module)
        case .wallpaper: return String(localized: "Wallpaper", bundle: .module)
        }
    }
}

public enum ShadowPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case soft
    case medium
    case strong

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return String(localized: "None", bundle: .module)
        case .soft: return String(localized: "Soft", bundle: .module)
        case .medium: return String(localized: "Medium", bundle: .module)
        case .strong: return String(localized: "Strong", bundle: .module)
        }
    }

    /// Blur radius in points.
    public var blur: Double {
        switch self {
        case .none: return 0
        case .soft: return 12
        case .medium: return 24
        case .strong: return 40
        }
    }

    /// Downward offset in points.
    public var offsetY: Double {
        switch self {
        case .none: return 0
        case .soft: return 4
        case .medium: return 10
        case .strong: return 18
        }
    }

    public var opacity: Double {
        switch self {
        case .none: return 0
        case .soft: return 0.25
        case .medium: return 0.4
        case .strong: return 0.55
        }
    }
}

public enum AspectPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case ratio16x9
    case ratio4x3
    case ratio1x1
    case ratio9x16
    case twitter
    case linkedIn
    case appStore

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return String(localized: "Auto", bundle: .module)
        case .ratio16x9: return "16:9"
        case .ratio4x3: return "4:3"
        case .ratio1x1: return "1:1"
        case .ratio9x16: return "9:16"
        case .twitter: return "Twitter / X (1600×900)"
        case .linkedIn: return "LinkedIn (1200×627)"
        case .appStore: return String(localized: "App Store (2880×1800)", bundle: .module)
        }
    }

    /// Width / height for ratio presets; nil for `auto` and fixed sizes.
    public var ratio: Double? {
        switch self {
        case .ratio16x9: return 16.0 / 9.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio1x1: return 1
        case .ratio9x16: return 9.0 / 16.0
        case .auto, .twitter, .linkedIn, .appStore: return nil
        }
    }

    /// Exact output size in pixels for platform presets.
    public var fixedPixelSize: CGSize? {
        switch self {
        case .twitter: return CGSize(width: 1600, height: 900)
        case .linkedIn: return CGSize(width: 1200, height: 627)
        case .appStore: return CGSize(width: 2880, height: 1800)
        case .auto, .ratio16x9, .ratio4x3, .ratio1x1, .ratio9x16: return nil
        }
    }
}

public enum BackdropAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case center
    case top
    case bottom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .center: return String(localized: "Center", bundle: .module)
        case .top: return String(localized: "Top", bundle: .module)
        case .bottom: return String(localized: "Bottom", bundle: .module)
        }
    }
}

/// Complete, serializable description of a backdrop composition.
public struct BackdropStyle: Codable, Equatable, Sendable {
    public static let paddingRange: ClosedRange<Double> = 0...200
    public static let cornerRadiusRange: ClosedRange<Double> = 0...40
    public static let contentScaleRange: ClosedRange<Double> = 0.5...1
    public static let wallpaperBlurRange: ClosedRange<Double> = 0...80

    public var background: BackgroundKind
    public var solidColor: RGBAColor
    public var gradient: GradientSpec
    /// Gaussian blur radius applied to the desktop wallpaper (points of the downsampled image).
    public var wallpaperBlur: Double
    /// Space around the screenshot, in points.
    public var padding: Double
    /// Corner radius of the screenshot, in points.
    public var cornerRadius: Double
    public var shadow: ShadowPreset
    /// Scale applied to the screenshot inside the canvas (inset), 0.5...1.
    public var contentScale: Double
    public var aspect: AspectPreset
    public var alignment: BackdropAlignment

    public init(
        background: BackgroundKind = .gradient,
        solidColor: RGBAColor = .white,
        gradient: GradientSpec = GradientPresets.all[0].spec,
        wallpaperBlur: Double = 30,
        padding: Double = 64,
        cornerRadius: Double = 12,
        shadow: ShadowPreset = .medium,
        contentScale: Double = 1,
        aspect: AspectPreset = .auto,
        alignment: BackdropAlignment = .center
    ) {
        self.background = background
        self.solidColor = solidColor
        self.gradient = gradient
        self.wallpaperBlur = wallpaperBlur
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.contentScale = contentScale
        self.aspect = aspect
        self.alignment = alignment
    }

    public static let standard = BackdropStyle()

    /// Copy with every numeric value clamped to its valid range (for decoded / external data).
    public func sanitized() -> BackdropStyle {
        var copy = self
        copy.padding = padding.clamped(to: Self.paddingRange)
        copy.cornerRadius = cornerRadius.clamped(to: Self.cornerRadiusRange)
        copy.contentScale = contentScale.clamped(to: Self.contentScaleRange)
        copy.wallpaperBlur = wallpaperBlur.clamped(to: Self.wallpaperBlurRange)
        return copy
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.lowerBound }
        return Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
