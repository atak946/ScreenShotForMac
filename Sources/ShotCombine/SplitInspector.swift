import ShotCore
import SwiftUI

/// Right-hand inspector for Split mode.
struct SplitInspector: View {
    @Bindable var model: CombineViewModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                directionSection
                Divider().padding(.horizontal, DS.Space.l)
                slicesSection
            }
            .padding(.vertical, DS.Space.xs)
        }
        .scrollIndicators(.automatic)
        .background(.ultraThinMaterial)
    }

    private var directionSection: some View {
        InspectorSection(title: String(localized: "Split", bundle: .module)) {
            Picker(String(localized: "Direction", bundle: .module), selection: $model.split.axis) {
                ForEach(SplitAxis.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker(String(localized: "Method", bundle: .module), selection: method) {
                ForEach(SplitMethod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            methodDetail
        }
    }

    @ViewBuilder private var methodDetail: some View {
        switch model.split.method {
        case .equal:
            LabeledStepper(
                title: String(localized: "Slices", bundle: .module),
                value: $model.split.count,
                range: SplitRenderer.countRange
            )
        case .custom:
            Text("Click the preview to add a line; hover a line to remove it.", bundle: .module)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Clear Lines", bundle: .module)) { model.split.customCuts = [] }
                .controlSize(.small)
                .disabled(model.split.customCuts.isEmpty)
        }
    }

    private var slicesSection: some View {
        InspectorSection(title: String(localized: "Slices", bundle: .module)) {
            if let source = model.splitSource {
                ForEach(Array(model.sliceRects.enumerated()), id: \.offset) { index, rect in
                    SliceRow(
                        index: index,
                        pixelSize: rect.size,
                        isSelected: index == model.selectedSliceIndex,
                        onSelect: { model.selectedSliceIndex = index },
                        onCopy: { model.copySlice(at: index) }
                    )
                }
                Text("Source: \(source.source.image.width) × \(source.source.image.height) px", bundle: .module)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button(String(localized: "Save All to Folder…", bundle: .module)) { model.saveAllSlices() }
                    .controlSize(.small)
                    .disabled(model.isExporting)
            } else {
                Text("Add an image to split.", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var method: Binding<SplitMethod> {
        Binding(get: { model.split.method }, set: { model.setSplitMethod($0) })
    }
}

/// One slice in the list: number, pixel size and a copy button.
private struct SliceRow: View {
    let index: Int
    let pixelSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Text(verbatim: "\(index + 1)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: 20, height: 20)
                .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Circle())
            Text(verbatim: "\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px")
                .font(.system(size: 12).monospacedDigit())
            Spacer()
            Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                .buttonStyle(ToolButtonStyle(size: 22))
                .help(String(localized: "Copy Slice", bundle: .module))
                .accessibilityLabel(Text("Copy Slice", bundle: .module))
        }
        .padding(.horizontal, DS.Space.xs)
        .padding(.vertical, DS.Space.xxs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .fill(Color.primary.opacity(isHovering || isSelected ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
