import ShotCore
import SwiftUI

/// Split mode canvas: the source image with its cut lines. In custom mode a click adds a
/// line, lines can be dragged, and each has a remove button.
struct SplitPreviewView: View {
    let model: CombineViewModel

    var body: some View {
        ZStack {
            DotGridBackground()
            content
                .padding(DS.Space.xxl)
                .padding(.bottom, DS.Space.l)
        }
        .overlay(alignment: .bottom) { hint }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Split preview", bundle: .module))
    }

    @ViewBuilder private var content: some View {
        if let item = model.splitSource {
            let image = item.preview.image
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: CGFloat(image.width), maxHeight: CGFloat(image.height))
                .overlay { SplitLinesOverlay(model: model) }
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        } else {
            EmptyWorkspaceView(model: model)
        }
    }

    private var hint: some View {
        Text("Click the image to add a split line. Drag lines to move them.", bundle: .module)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .glassSurface(cornerRadius: 10)
            .padding(.bottom, DS.Space.m)
            .opacity(model.splitSource == nil ? 0 : 1)
    }
}

/// Lines, slice numbers and interaction drawn over the fitted source image.
private struct SplitLinesOverlay: View {
    let model: CombineViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in
                        model.addCut(at: fraction(of: point, in: size))
                    }
                sliceLabels(in: size)
                ForEach(lines, id: \.index) { line in
                    SplitLineView(
                        axis: model.split.axis,
                        fraction: line.fraction,
                        size: size,
                        isEditable: model.split.method == .custom,
                        onDrag: { point in model.moveCut(at: line.index, to: fraction(of: point, in: size)) },
                        onDragEnd: { model.commitCuts() },
                        onRemove: { model.removeCut(at: line.index) }
                    )
                }
            }
            .coordinateSpace(name: SplitCoordinateSpace.name)
        }
    }

    private var lines: [(index: Int, fraction: Double)] {
        let values = model.split.method == .custom ? model.split.customCuts : model.split.cuts
        return values.enumerated().map { (index: $0.offset, fraction: $0.element) }
    }

    private func fraction(of point: CGPoint, in size: CGSize) -> Double {
        let value = model.split.axis == .horizontal ? point.y / max(size.height, 1) : point.x / max(size.width, 1)
        return Double(value).clamped(to: 0.01...0.99)
    }

    private func sliceLabels(in size: CGSize) -> some View {
        let edges = [0] + model.split.cuts + [1]
        let isHorizontal = model.split.axis == .horizontal
        return ForEach(Array(zip(edges, edges.dropFirst()).enumerated()), id: \.offset) { index, span in
            let mid = CGFloat((span.0 + span.1) / 2)
            Text(verbatim: "\(index + 1)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(index == model.selectedSliceIndex ? Color.white : Color.primary)
                .frame(width: 22, height: 22)
                .background(
                    index == model.selectedSliceIndex ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                    in: Circle()
                )
                .position(
                    x: isHorizontal ? DS.Space.l + DS.Space.xs : size.width * mid,
                    y: isHorizontal ? size.height * mid : DS.Space.l + DS.Space.xs
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// One cut line with a drag handle and a remove button (custom mode only).
private struct SplitLineView: View {
    let axis: SplitAxis
    let fraction: Double
    let size: CGSize
    let isEditable: Bool
    let onDrag: (CGPoint) -> Void
    let onDragEnd: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    private static let hitThickness: CGFloat = 12

    var body: some View {
        let isHorizontal = axis == .horizontal
        let position = CGFloat(fraction) * (isHorizontal ? size.height : size.width)
        ZStack {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: isHorizontal ? size.width : 2, height: isHorizontal ? 2 : size.height)
                .shadow(color: .black.opacity(0.35), radius: 1.5)
            if isEditable, isHovering { removeButton }
        }
        .frame(
            width: isHorizontal ? size.width : Self.hitThickness,
            height: isHorizontal ? Self.hitThickness : size.height
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            guard isEditable else { return }
            if hovering {
                (isHorizontal ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovering, isEditable { NSCursor.pop() }
        }
        .gesture(dragGesture, including: isEditable ? .all : .none)
        .position(x: isHorizontal ? size.width / 2 : position, y: isHorizontal ? position : size.height / 2)
        .accessibilityElement()
        .accessibilityLabel(Text("Split line", bundle: .module))
        .accessibilityValue(Text(verbatim: "\(Int((fraction * 100).rounded()))%"))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(SplitCoordinateSpace.name))
            .onChanged { onDrag($0.location) }
            .onEnded { _ in onDragEnd() }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.black.opacity(0.7), in: Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Remove Line", bundle: .module))
        .accessibilityLabel(Text("Remove Line", bundle: .module))
    }
}

enum SplitCoordinateSpace {
    static let name = "splitOverlay"
}
