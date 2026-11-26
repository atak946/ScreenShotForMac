import AppKit
import ShotCore
import SwiftUI

/// What the floating bar at the bottom of the canvas shows.
enum StyleBarMode: Equatable {
    case hidden
    case crop
    /// Options for `tool`; `hasSelection` = editing an existing annotation.
    case style(tool: EditorTool, hasSelection: Bool)

    @MainActor
    init(viewModel: EditorViewModel) {
        if viewModel.tool == .crop {
            self = .crop
            return
        }
        let hasSelection = viewModel.selectedAnnotation != nil
        let tool: EditorTool? = if let selected = viewModel.selectedAnnotation {
            EditorTool(kind: selected.kind)
        } else {
            viewModel.tool == .select ? nil : viewModel.tool
        }
        guard let tool, StyleOptions(tool: tool, hasSelection: hasSelection).hasAny else {
            self = .hidden
            return
        }
        self = .style(tool: tool, hasSelection: hasSelection)
    }
}

/// Which controls apply to a tool.
struct StyleOptions {
    let color: Bool
    let width: Bool
    let dashed: Bool
    let fill: Bool
    let arrowHeads: Bool
    let cornerRadius: Bool
    let fontSize: Bool
    let opacity: Bool
    let redactionMode: Bool

    init(tool: EditorTool, hasSelection: Bool) {
        color = tool.usesColor
        width = [.arrow, .line, .rectangle, .ellipse, .pen, .magnifier].contains(tool)
        dashed = tool.usesLineStyle
        fill = tool.usesFill
        arrowHeads = tool == .arrow
        cornerRadius = tool.usesCornerRadius
        fontSize = tool.usesFontSize
        opacity = tool == .spotlight
        // An existing annotation can't change kind, so the mode switch is for new ones only.
        redactionMode = !hasSelection && (tool == .blur || tool == .pixelate)
    }

    var hasAny: Bool { color || width || dashed || fill || arrowHeads || cornerRadius || fontSize || opacity || redactionMode }
}

/// Floating glass capsule centered at the bottom of the canvas. Keeps the last content
/// while fading out so the hide animation doesn't collapse to nothing.
struct StyleBar: View {
    private static let hiddenOffset: CGFloat = 10

    let viewModel: EditorViewModel
    @State private var shown: StyleBarMode = .hidden

    private var mode: StyleBarMode { StyleBarMode(viewModel: viewModel) }
    private var isVisible: Bool { mode != .hidden }

    var body: some View {
        content(for: isVisible ? mode : shown)
            .padding(.horizontal, DS.Space.s)
            .frame(height: DS.Size.toolbarHeight - 4)
            .glassSurface(cornerRadius: (DS.Size.toolbarHeight - 4) / 2)
            .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
            .fixedSize()
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : Self.hiddenOffset)
            .scaleEffect(isVisible ? 1 : 0.97, anchor: .bottom)
            .allowsHitTesting(isVisible)
            .animation(DS.Motion.spring, value: mode)
            .onAppear { shown = mode }
            .onChange(of: mode) { _, newMode in
                if newMode != .hidden { shown = newMode }
            }
    }

    @ViewBuilder
    private func content(for mode: StyleBarMode) -> some View {
        switch mode {
        case .hidden:
            EmptyView()
        case .crop:
            CropBarContent(viewModel: viewModel)
        case let .style(tool, hasSelection):
            StyleBarContent(viewModel: viewModel, tool: tool, options: StyleOptions(tool: tool, hasSelection: hasSelection))
        }
    }
}

/// Hosting view for the style bar that lets clicks fall through to the canvas while hidden.
@MainActor
final class StyleBarHostingView: NSHostingView<StyleBar> {
    private let viewModel: EditorViewModel

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        super.init(rootView: StyleBar(viewModel: viewModel))
        sizingOptions = [.intrinsicContentSize]
    }

    @available(*, unavailable)
    required init(rootView: StyleBar) { fatalError("init(rootView:) is not supported") }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        StyleBarMode(viewModel: viewModel) == .hidden ? nil : super.hitTest(point)
    }
}
