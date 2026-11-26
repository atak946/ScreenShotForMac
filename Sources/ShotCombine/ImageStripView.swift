import ShotCore
import SwiftUI
import UniformTypeIdentifiers

/// Bottom strip of thumbnails: drag to reorder, × on hover to remove, "+" to add.
struct ImageStripView: View {
    static let height: CGFloat = 96
    static let thumbnailHeight: CGFloat = 64

    let model: CombineViewModel
    @State private var draggedID: UUID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.s) {
                ForEach(model.items) { item in
                    StripThumbnail(
                        item: item,
                        isSelected: item.id == model.selectedItemID,
                        onSelect: { model.selectedItemID = item.id },
                        onRemove: { withAnimation(DS.Motion.spring) { model.remove(id: item.id) } }
                    )
                    .opacity(draggedID == item.id ? 0.4 : 1)
                    .onDrag {
                        draggedID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: ReorderDropDelegate(target: item.id, draggedID: $draggedID, model: model)
                    )
                }
                addButton
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.m)
        }
        .scrollIndicators(.never)
        .frame(height: Self.height)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Images", bundle: .module))
    }

    private var addButton: some View {
        Button { model.addFromPanel() } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.thumbnailHeight, height: Self.thumbnailHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Add Images… (⌘O)", bundle: .module))
        .accessibilityLabel(Text("Add Images", bundle: .module))
    }
}

/// Reorders live while an item is dragged over another one.
private struct ReorderDropDelegate: DropDelegate {
    let target: UUID
    @Binding var draggedID: UUID?
    let model: CombineViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != target else { return }
        withAnimation(DS.Motion.spring) { model.move(draggedID, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedID != nil
    }
}

/// One thumbnail with selection ring and hover remove button.
private struct StripThumbnail: View {
    let item: CombineItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        let height = ImageStripView.thumbnailHeight
        let aspect = CGFloat(item.thumbnail.width) / CGFloat(max(item.thumbnail.height, 1))
        let width = min(max(height * aspect, height * 0.6), height * 2.2)
        Image(decorative: item.thumbnail, scale: 1)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(Color.dsStroke, lineWidth: DS.Size.hairline)
            )
            .padding(3)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card + 3, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
            )
            .overlay(alignment: .topTrailing) { if isHovering { removeButton } }
            .scaleEffect(isHovering && !isSelected ? 1.03 : 1)
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onHover { isHovering = $0 }
            .help(Text(verbatim: "\(item.source.image.width) × \(item.source.image.height) px"))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Image \(item.source.image.width) by \(item.source.image.height) pixels", bundle: .module))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: Text("Remove", bundle: .module), onRemove)
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.black.opacity(0.72), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
        .help(String(localized: "Remove", bundle: .module))
        .accessibilityLabel(Text("Remove", bundle: .module))
        .transition(.opacity)
    }
}
