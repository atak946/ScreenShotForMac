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

/// Circular dial for a CSS-style angle (0° = up, clockwise). Hold ⇧ to snap to 15°.
struct AngleDial: View {
    @Binding var angle: Double
    private static let side: CGFloat = 30
    private static let snapStep: Double = 15

    var body: some View {
        let side = Self.side
        ZStack {
            Circle().fill(Color.primary.opacity(0.06))
            Circle().strokeBorder(Color.dsStroke, lineWidth: 1)
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 2, height: side / 2 - 5)
                .offset(y: -(side / 4 - 2.5))
                .rotationEffect(.degrees(angle))
            Circle().fill(Color.accentColor).frame(width: 4, height: 4)
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            angle = Self.angle(at: value.location, side: side)
        })
        .accessibilityElement()
        .accessibilityLabel(Text("Angle", bundle: .module))
        .accessibilityValue(Text(verbatim: "\(Int(angle))°"))
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? Self.snapStep : -Self.snapStep
            angle = (angle + delta + 360).truncatingRemainder(dividingBy: 360)
        }
    }

    private static func angle(at point: CGPoint, side: CGFloat) -> Double {
        let dx = point.x - side / 2
        let dy = side / 2 - point.y
        var degrees = atan2(dx, dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        if NSEvent.modifierFlags.contains(.shift) {
            return ((degrees / snapStep).rounded() * snapStep).truncatingRemainder(dividingBy: 360)
        }
        return degrees.rounded()
    }
}

/// Grid of curated gradient swatches with a selection ring.
struct GradientSwatchGrid: View {
    let selected: GradientSpec
    let onSelect: (GradientPreset) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Space.s) {
            ForEach(GradientPresets.all) { preset in
                GradientSwatch(
                    preset: preset,
                    isSelected: preset.spec.start == selected.start && preset.spec.end == selected.end
                ) { onSelect(preset) }
            }
        }
    }
}

private struct GradientSwatch: View {
    let preset: GradientPreset
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .fill(preset.spec.linearGradient)
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                        .strokeBorder(Color.dsStroke, lineWidth: DS.Size.hairline)
                )
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.control + 3, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isHovering && !isSelected ? 1.05 : 1)
                .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
                .animation(.easeOut(duration: DS.Motion.fast), value: isSelected)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(preset.name)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension GradientSpec {
    /// SwiftUI gradient matching the renderer's CSS-style angle.
    var linearGradient: LinearGradient {
        let radians = angle * .pi / 180
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        return LinearGradient(
            colors: [Color(cgColor: start.cgColor), Color(cgColor: end.cgColor)],
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }
}

extension AspectPreset {
    var systemImage: String {
        switch self {
        case .auto: return "aspectratio"
        case .ratio16x9: return "rectangle.ratio.16.to.9"
        case .ratio4x3: return "rectangle.ratio.4.to.3"
        case .ratio1x1: return "square"
        case .ratio9x16: return "rectangle.ratio.9.to.16"
        case .twitter: return "text.bubble"
        case .linkedIn: return "briefcase"
        case .appStore: return "laptopcomputer"
        }
    }
}

extension BackdropAlignment {
    var systemImage: String {
        switch self {
        case .center: return "align.vertical.center"
        case .top: return "align.vertical.top"
        case .bottom: return "align.vertical.bottom"
        }
    }
}

extension RGBAColor {
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
