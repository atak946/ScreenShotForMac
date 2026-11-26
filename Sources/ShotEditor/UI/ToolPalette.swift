import ShotCore
import SwiftUI

/// Center toolbar zone: the tool palette as one glass capsule.
/// Collapses groups into menus progressively so it never wraps or scrolls.
struct ToolPalette: View {
    private static let inset: CGFloat = 3

    let viewModel: EditorViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            capsule(.full)
            capsule(.compact)
            capsule(.minimal)
            capsule(.tiny)
        }
    }

    private func capsule(_ density: PaletteDensity) -> some View {
        PaletteRow(viewModel: viewModel, density: density)
            .padding(Self.inset)
            .glassSurface(cornerRadius: DS.Size.iconButton / 2 + Self.inset)
            .fixedSize()
    }
}

enum PaletteDensity {
    /// Every tool visible.
    case full
    /// Spotlight / Magnifier / Smart Erase move into "More".
    case compact
    /// Shapes collapse too; Blur / Pixelate join "More".
    case minimal
    /// Text, Counter, Highlight and Pen collapse into one markup menu.
    case tiny
}

private struct PaletteRow: View {
    let viewModel: EditorViewModel
    let density: PaletteDensity

    private static let shapes: [EditorTool] = [.arrow, .line, .rectangle, .ellipse]
    private static let markup: [EditorTool] = [.text, .counter, .highlight, .pen]
    private static let rare: [EditorTool] = [.spotlight, .magnifier, .fill]

    var body: some View {
        HStack(spacing: 2) {
            tool(.select)
            ToolbarDivider()
            shapes
            ToolbarDivider()
            markup
            ToolbarDivider()
            effects
            ToolbarDivider()
            tool(.crop)
        }
    }

    @ViewBuilder private var shapes: some View {
        if density == .full || density == .compact {
            ForEach(Self.shapes) { tool($0) }
        } else {
            ToolGroupMenu(
                viewModel: viewModel,
                tools: Self.shapes,
                symbol: "square.on.circle",
                help: String(localized: "Shapes", bundle: .module)
            )
        }
    }

    @ViewBuilder private var markup: some View {
        if density == .tiny {
            ToolGroupMenu(
                viewModel: viewModel,
                tools: Self.markup,
                symbol: "pencil.tip",
                help: String(localized: "Markup", bundle: .module)
            )
        } else {
            tool(.text)
            tool(.counter)
            ToolbarDivider()
            tool(.highlight)
            tool(.pen)
        }
    }

    @ViewBuilder private var effects: some View {
        switch density {
        case .full:
            RedactionButton(viewModel: viewModel)
            ForEach(Self.rare) { tool($0) }
        case .compact:
            RedactionButton(viewModel: viewModel)
            moreMenu(Self.rare)
        case .minimal, .tiny:
            moreMenu([.blur, .pixelate] + Self.rare)
        }
    }

    private func moreMenu(_ tools: [EditorTool]) -> some View {
        ToolGroupMenu(viewModel: viewModel, tools: tools, symbol: "ellipsis", help: String(localized: "More Tools", bundle: .module))
    }

    private func tool(_ tool: EditorTool) -> some View {
        Button { viewModel.selectToolAnimated(tool) } label: {
            Image(systemName: tool.systemImage)
        }
        .buttonStyle(ToolButtonStyle(isSelected: viewModel.tool == tool))
        .help(tool.tooltip)
        .accessibilityLabel(tool.title)
    }
}

/// Blur / Pixelate: one button for the last used mode plus a chevron to switch.
private struct RedactionButton: View {
    let viewModel: EditorViewModel
    @State private var anchor = MenuAnchor()
    @State private var isHovering = false

    private var current: EditorTool { viewModel.redactionTool }
    private var isSelected: Bool { viewModel.tool == .blur || viewModel.tool == .pixelate }

    var body: some View {
        HStack(spacing: 0) {
            Button { viewModel.selectToolAnimated(current) } label: {
                Image(systemName: current.systemImage)
                    .font(.system(size: DS.Size.symbolPointSize, weight: .medium))
                    .frame(width: DS.Size.iconButton - 2, height: DS.Size.iconButton)
                    .contentShape(Rectangle())
            }
            .help(current.tooltip)
            .accessibilityLabel(current.title)
            Button { anchor.popUp(entries) } label: {
                MenuChevron()
                    .frame(width: 12, height: DS.Size.iconButton)
                    .contentShape(Rectangle())
            }
            .menuAnchor(anchor)
            .help(String(localized: "Redaction Mode", bundle: .module))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
        .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor) }
        return AnyShapeStyle(Color.primary.opacity(isHovering ? 0.08 : 0))
    }

    private var entries: [MenuEntry] {
        [EditorTool.blur, .pixelate].map { tool in
            .action(tool.title, symbol: tool.systemImage, isOn: tool == current, key: String(tool.shortcut)) {
                viewModel.selectToolAnimated(tool)
            }
        }
    }
}

/// Collapsed tool group: shows the active member's icon (or `symbol`) and lists the group in a menu.
private struct ToolGroupMenu: View {
    let viewModel: EditorViewModel
    let tools: [EditorTool]
    let symbol: String
    let help: String

    private var activeTool: EditorTool? { tools.first { $0 == viewModel.tool } }

    var body: some View {
        PopUpMenuButton(help: activeTool?.tooltip ?? help, isSelected: activeTool != nil, entries: { entries }) {
            HStack(spacing: 2) {
                Image(systemName: activeTool?.systemImage ?? symbol)
                    .font(.system(size: DS.Size.symbolPointSize, weight: .medium))
                MenuChevron()
            }
        }
    }

    private var entries: [MenuEntry] {
        tools.map { tool in
            .action(tool.title, symbol: tool.systemImage, isOn: tool == viewModel.tool, key: String(tool.shortcut)) {
                viewModel.selectToolAnimated(tool)
            }
        }
    }
}

extension EditorViewModel {
    /// Tool switch from the chrome, animated so selection fills and the style bar glide.
    func selectToolAnimated(_ tool: EditorTool) {
        withAnimation(DS.Motion.spring) { selectTool(tool) }
    }
}
