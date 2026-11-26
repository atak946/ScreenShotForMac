import AppKit
import ShotCore
import SwiftUI

/// Options for the current tool / selected annotation, grouped with dividers.
struct StyleBarContent: View {
    private static let controlSize: CGFloat = 26

    let viewModel: EditorViewModel
    let tool: EditorTool
    let options: StyleOptions

    private var style: AnnotationStyle {
        viewModel.selectedAnnotation?.style ?? viewModel.creationStyle(for: tool)
    }

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            if options.redactionMode { redactionModes }
            if options.color { ColorSwatchRow(viewModel: viewModel, current: style.color) }
            if options.color, hasShapeGroup { ToolbarDivider() }
            if options.width { widthDots }
            if options.dashed || options.fill || options.arrowHeads { toggles }
            if options.cornerRadius { cornerRadiusMenu }
            if options.fontSize { fontSizeMenu }
            if options.opacity { opacityMenu }
        }
    }

    private var hasShapeGroup: Bool {
        options.width || options.dashed || options.fill || options.arrowHeads || options.cornerRadius || options.fontSize
    }

    private var redactionModes: some View {
        HStack(spacing: 2) {
            ForEach([EditorTool.blur, .pixelate]) { mode in
                Button { viewModel.selectToolAnimated(mode) } label: {
                    Label(mode.title, systemImage: mode.systemImage).labelStyle(.titleAndIcon)
                }
                .buttonStyle(ChromeButtonStyle(isSelected: tool == mode, height: Self.controlSize))
                .help(mode.tooltip)
            }
        }
    }

    private var widthDots: some View {
        HStack(spacing: 0) {
            ForEach(Array(AnnotationStyle.lineWidths.enumerated()), id: \.offset) { index, width in
                Button { viewModel.setLineWidth(width) } label: {
                    Circle().frame(width: CGFloat(4 + index * 3), height: CGFloat(4 + index * 3))
                }
                .buttonStyle(ToolButtonStyle(isSelected: style.lineWidth == width, size: Self.controlSize))
                .help(String(localized: "Line Width", bundle: .module) + " \(Int(width)) px")
            }
        }
    }

    @ViewBuilder private var toggles: some View {
        if options.dashed {
            Button { viewModel.setDashed(!style.dashed) } label: { DashedLineGlyph() }
                .buttonStyle(ToolButtonStyle(isSelected: style.dashed, size: Self.controlSize))
                .help(String(localized: "Dashed Line", bundle: .module))
        }
        if options.fill {
            Button { viewModel.setFilled(!style.filled) } label: {
                Image(systemName: tool == .text ? "character.textbox" : "square.fill")
            }
            .buttonStyle(ToolButtonStyle(isSelected: style.filled, size: Self.controlSize))
            .help(tool == .text ? String(localized: "Text Background", bundle: .module) : String(
                localized: "Filled Shape",
                bundle: .module
            ))
        }
        if options.arrowHeads { arrowHeads }
    }

    private var arrowHeads: some View {
        HStack(spacing: 0) {
            Button { viewModel.setDoubleHeaded(false) } label: { Image(systemName: "arrow.right") }
                .buttonStyle(ToolButtonStyle(isSelected: !style.doubleHeaded, size: Self.controlSize))
                .help(String(localized: "Single Arrow Head", bundle: .module))
            Button { viewModel.setDoubleHeaded(true) } label: { Image(systemName: "arrow.left.and.right") }
                .buttonStyle(ToolButtonStyle(isSelected: style.doubleHeaded, size: Self.controlSize))
                .help(String(localized: "Arrow Head on Both Ends", bundle: .module))
        }
    }

    private var cornerRadiusMenu: some View {
        valueMenu(symbol: "square.dashed", value: "\(Int(style.cornerRadius))", help: String(localized: "Corner Radius", bundle: .module)) {
            AnnotationStyle.cornerRadii.map { radius in
                let title = radius == 0 ? String(localized: "Square", bundle: .module) : "\(Int(radius)) pt"
                return .action(title, isOn: style.cornerRadius == radius) { viewModel.setCornerRadius(radius) }
            }
        }
    }

    private var fontSizeMenu: some View {
        valueMenu(symbol: "textformat.size", value: "\(Int(style.fontSize))", help: String(localized: "Text Size", bundle: .module)) {
            AnnotationStyle.fontSizes.map { size in
                .action("\(Int(size)) pt", isOn: style.fontSize == size) { viewModel.setFontSize(size) }
            }
        }
    }

    private var opacityMenu: some View {
        let current = viewModel.document.spotlightOpacity
        return valueMenu(
            symbol: "circle.lefthalf.filled",
            value: "\(Int(current * 100))%",
            help: String(localized: "Spotlight Dimming", bundle: .module)
        ) {
            EditorDocument.spotlightOpacities.map { opacity in
                .action("\(Int(opacity * 100))%", isOn: abs(current - opacity) < 0.001) { viewModel.setSpotlightOpacity(opacity) }
            }
        }
    }

    private func valueMenu(symbol: String, value: String, help: String, entries: @escaping () -> [MenuEntry]) -> some View {
        PopUpMenuButton(help: help, entries: entries) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                Text(value).font(.system(size: 12, weight: .medium).monospacedDigit())
                MenuChevron()
            }
        }
    }
}

/// Seven curated swatches plus a custom color button.
private struct ColorSwatchRow: View {
    let viewModel: EditorViewModel
    let current: AnnotationColor

    private var isCustom: Bool { !AnnotationColor.palette.contains(current) }

    private func showColorPanel() {
        let model = viewModel
        ColorPanelBridge.shared.show(color: current) { [weak model] color in model?.setColor(color) }
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(AnnotationColor.palette, id: \.self) { color in
                SwatchButton(fill: AnyShapeStyle(Color(nsColor: color.nsColor)), isSelected: current == color) {
                    viewModel.setColor(color)
                }
            }
            SwatchButton(fill: AnyShapeStyle(AngularGradient.rainbow), isSelected: isCustom, action: showColorPanel)
                .help(String(localized: "Custom Color", bundle: .module))
        }
    }
}

private struct SwatchButton: View {
    private static let diameter: CGFloat = 16

    let fill: AnyShapeStyle
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
                .frame(width: Self.diameter, height: Self.diameter)
                .padding(3)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
                .scaleEffect(isHovering && !isSelected ? 1.1 : 1)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
        .animation(.easeOut(duration: DS.Motion.fast), value: isSelected)
        .onHover { isHovering = $0 }
    }
}

private struct DashedLineGlyph: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height - 2))
            path.addLine(to: CGPoint(x: size.width - 2, y: 2))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [3, 3]))
        }
        .frame(width: 14, height: 14)
    }
}

extension AngularGradient {
    fileprivate static var rainbow: AngularGradient {
        AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)
    }
}

/// Routes `NSColorPanel` changes to the editor that opened it.
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var handler: ((AnnotationColor) -> Void)?

    func show(color: AnnotationColor, onChange: @escaping (AnnotationColor) -> Void) {
        let panel = NSColorPanel.shared
        handler = nil
        panel.showsAlpha = false
        panel.color = color.nsColor
        handler = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc
    private func colorChanged(_ sender: NSColorPanel) {
        handler?(AnnotationColor(nsColor: sender.color))
    }
}
