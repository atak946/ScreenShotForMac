import AppKit
import ShotCore
import SwiftUI

/// Titled group in the inspector sidebar.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            InspectorHeader(title: title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m + DS.Space.xxs)
    }
}

/// Small secondary heading used by inspector sections.
struct InspectorHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Slider with a title and a numeric readout.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(verbatim: "\(Int(value.rounded()))\(unit)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }
}

/// Title + stepper with a numeric readout.
struct LabeledStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            Text(verbatim: "\(value)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Stepper(title, value: $value, in: range)
                .labelsHidden()
                .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

extension CombineArrangement {
    var title: String {
        switch self {
        case .vertical: return String(localized: "Vertical", bundle: .module)
        case .horizontal: return String(localized: "Horizontal", bundle: .module)
        case .grid: return String(localized: "Grid", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .vertical: return "rectangle.split.1x2"
        case .horizontal: return "rectangle.split.2x1"
        case .grid: return "square.grid.2x2"
        }
    }
}

extension CombineAlignment {
    var title: String {
        switch self {
        case .start: return String(localized: "Start", bundle: .module)
        case .center: return String(localized: "Center", bundle: .module)
        case .end: return String(localized: "End", bundle: .module)
        }
    }

    func systemImage(for arrangement: CombineArrangement) -> String {
        let isVertical = arrangement != .horizontal
        switch self {
        case .start: return isVertical ? "align.horizontal.left" : "align.vertical.top"
        case .center: return isVertical ? "align.horizontal.center" : "align.vertical.center"
        case .end: return isVertical ? "align.horizontal.right" : "align.vertical.bottom"
        }
    }
}

extension SplitAxis {
    var title: String {
        switch self {
        case .horizontal: return String(localized: "Horizontal Slices", bundle: .module)
        case .vertical: return String(localized: "Vertical Slices", bundle: .module)
        }
    }
}

extension SplitMethod {
    var title: String {
        switch self {
        case .equal: return String(localized: "Equal", bundle: .module)
        case .custom: return String(localized: "Custom Lines", bundle: .module)
        }
    }
}

extension CombineColor {
    /// Converts a SwiftUI color to sRGB components; falls back to white if conversion fails.
    init(color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else {
            self = .white
            return
        }
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
