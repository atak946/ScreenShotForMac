import ShotCore
import SwiftUI

/// Editor bar hosted as the single item of a unified `NSToolbar` (see `EditorToolbarHost`).
/// Leading: Undo / Redo (+ image size). Center: tool palette. Trailing: zoom, more, export.
/// Keyboard shortcuts are handled by `CanvasView` (no main menu in an LSUIElement app).
struct EditorToolbarView: View {
    /// Height of the toolbar item; AppKit centers it (and the traffic lights) in the titlebar.
    static let height: CGFloat = 36
    /// The window's center sits this far left of the bar's center (traffic lights take the leading space).
    private static let centerBias: CGFloat = -EditorToolbarHost.reservedWidth / 2
    /// Window width from which the image size is shown next to Undo / Redo.
    private static let dimensionsMinWidth: CGFloat = 960

    let viewModel: EditorViewModel

    var body: some View {
        GeometryReader { proxy in
            ToolbarZonesLayout(
                spacing: DS.Space.m,
                centerBias: Self.centerBias
            ) {
                LeadingToolbarItems(viewModel: viewModel, showsDimensions: proxy.size.width >= Self.dimensionsMinWidth)
                ToolPalette(viewModel: viewModel)
                TrailingToolbarItems(viewModel: viewModel)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background { WindowDragArea() }
    }
}

/// Places subviews [leading, center, trailing]: leading/trailing at their ideal sizes on the
/// edges, center at the window's midpoint when it fits, otherwise centered in the gap.
/// The center gets the remaining width as its proposal, so `ViewThatFits` can collapse it.
struct ToolbarZonesLayout: Layout {
    private static let defaultHeight: CGFloat = 36

    let spacing: CGFloat
    /// Offset of the window center from the layout's own center.
    let centerBias: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width }
        return CGSize(
            width: proposal.width ?? ideal + spacing * 2,
            height: proposal.height ?? Self.defaultHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let leading = subviews[0].sizeThatFits(.unspecified)
        let trailing = subviews[2].sizeThatFits(.unspecified)
        let gapMin = bounds.minX + leading.width + spacing
        let gapMax = bounds.maxX - trailing.width - spacing
        let center = subviews[1].sizeThatFits(ProposedViewSize(width: max(gapMax - gapMin, 0), height: bounds.height))

        let idealMinX = bounds.midX + centerBias - center.width / 2
        let centerMinX = min(max(idealMinX, gapMin), max(gapMax - center.width, gapMin))

        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        subviews[1].place(
            at: CGPoint(x: centerMinX, y: bounds.midY), anchor: .leading,
            proposal: ProposedViewSize(width: center.width, height: bounds.height)
        )
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)
    }
}

/// Undo / Redo and the output size.
private struct LeadingToolbarItems: View {
    let viewModel: EditorViewModel
    let showsDimensions: Bool

    var body: some View {
        HStack(spacing: 2) {
            Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!viewModel.canUndo)
                .help(String(localized: "Undo", bundle: .module) + "  ⌘Z")
                .accessibilityLabel(String(localized: "Undo", bundle: .module))
            Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!viewModel.canRedo)
                .help(String(localized: "Redo", bundle: .module) + "  ⇧⌘Z")
                .accessibilityLabel(String(localized: "Redo", bundle: .module))
            if showsDimensions {
                Text(viewModel.outputDimensionsLabel)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Space.s)
                    .help(String(localized: "Image Size in Pixels", bundle: .module))
            }
        }
    }
}

extension EditorViewModel {
    /// "1920 × 1080": exported size in pixels.
    var outputDimensionsLabel: String {
        let rect = document.outputRect
        let scale = document.scale
        return "\(Int((rect.width * scale).rounded())) × \(Int((rect.height * scale).rounded()))"
    }
}
