import CoreGraphics
import Foundation

/// Unit used for labels and copied text.
enum MeasureUnit: Sendable {
    case points
    case pixels

    var toggled: MeasureUnit { self == .points ? .pixels : .points }
    var suffix: String { self == .points ? "pt" : "px" }
}

/// Formats pixel lengths as point / pixel strings.
struct MeasureFormatter: Sendable {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let primary: MeasureUnit
    /// Also show the secondary unit (Shift held).
    let showsSecondary: Bool

    func width(_ pixels: Int) -> String { label(pixels, scale: scaleX) }

    func height(_ pixels: Int) -> String { label(pixels, scale: scaleY) }

    /// Box label, e.g. "120 × 48 pt  ·  240 × 96 px".
    func size(width: Int, height: Int) -> String {
        let pointText = "\(Self.number(CGFloat(width) / scaleX)) × \(Self.number(CGFloat(height) / scaleY)) pt"
        let pixelText = "\(width) × \(height) px"
        return primary == .points ? "\(pointText)  ·  \(pixelText)" : "\(pixelText)  ·  \(pointText)"
    }

    /// Clipboard text in the primary unit, e.g. "120 × 48".
    func copyText(width: Int, height: Int) -> String {
        "\(value(width, scale: scaleX, unit: primary)) × \(value(height, scale: scaleY, unit: primary))"
    }

    private func label(_ pixels: Int, scale: CGFloat) -> String {
        let main = "\(value(pixels, scale: scale, unit: primary)) \(primary.suffix)"
        guard showsSecondary else { return main }
        let secondary = primary.toggled
        return "\(main) · \(value(pixels, scale: scale, unit: secondary)) \(secondary.suffix)"
    }

    private func value(_ pixels: Int, scale: CGFloat, unit: MeasureUnit) -> String {
        unit == .pixels ? String(pixels) : Self.number(CGFloat(pixels) / scale)
    }

    /// Integer when whole, otherwise one decimal.
    static func number(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", Double(rounded))
    }
}
