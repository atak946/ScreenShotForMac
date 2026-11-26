import Foundation
import ShotCore

/// Formats picked colors as code-ready strings.
public enum ColorFormatter {
    public static func string(for color: PickedColor, format: ColorFormat) -> String {
        switch format {
        case .hex: return hex(color)
        case .rgb: return rgb(color)
        case .hsl: return hsl(color)
        case .swiftUI: return swiftUI(color)
        case .nsColor: return nsColor(color)
        }
    }

    private static func hex(_ color: PickedColor) -> String {
        let base = String(format: "#%02X%02X%02X", byte(color.red), byte(color.green), byte(color.blue))
        return color.alpha < 1 ? base + String(format: "%02X", byte(color.alpha)) : base
    }

    private static func rgb(_ color: PickedColor) -> String {
        "rgb(\(byte(color.red)), \(byte(color.green)), \(byte(color.blue)))"
    }

    private static func hsl(_ color: PickedColor) -> String {
        let (h, s, l) = hslComponents(color)
        return "hsl(\(Int(h.rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
    }

    private static func swiftUI(_ color: PickedColor) -> String {
        let base = "Color(red: \(decimal(color.red)), green: \(decimal(color.green)), blue: \(decimal(color.blue))"
        return color.alpha < 1 ? base + ", opacity: \(decimal(color.alpha)))" : base + ")"
    }

    private static func nsColor(_ color: PickedColor) -> String {
        let alpha = color.alpha < 1 ? decimal(color.alpha) : "1"
        return "NSColor(srgbRed: \(decimal(color.red)), green: \(decimal(color.green)), "
            + "blue: \(decimal(color.blue)), alpha: \(alpha))"
    }

    /// Hue in degrees (0..<360), saturation and lightness in 0...1.
    static func hslComponents(_ color: PickedColor) -> (Double, Double, Double) {
        let r = clamp(color.red), g = clamp(color.green), b = clamp(color.blue)
        let maxValue = max(r, g, b), minValue = min(r, g, b)
        let lightness = (maxValue + minValue) / 2
        let delta = maxValue - minValue
        guard delta > 0 else { return (0, 0, lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double = switch maxValue {
        case r: 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        case g: 60 * ((b - r) / delta + 2)
        default: 60 * ((r - g) / delta + 4)
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue
        return (normalizedHue >= 359.5 ? 0 : normalizedHue, min(saturation, 1), lightness)
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static func byte(_ value: Double) -> Int { Int((clamp(value) * 255).rounded()) }

    private static func decimal(_ value: Double) -> String { String(format: "%.3f", clamp(value)) }
}
