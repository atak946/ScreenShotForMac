import ShotCore
import SwiftUI

/// Right-hand inspector for Combine mode.
struct CombineInspector: View {
    @Bindable var model: CombineViewModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                layoutSection
                divider
                spacingSection
                divider
                backgroundSection
                divider
                imagesSection
            }
            .padding(.vertical, DS.Space.xs)
        }
        .scrollIndicators(.automatic)
        .background(.ultraThinMaterial)
    }

    private var divider: some View {
        Divider().padding(.horizontal, DS.Space.l)
    }

    // MARK: Sections

    private var layoutSection: some View {
        InspectorSection(title: String(localized: "Layout", bundle: .module)) {
            Picker(String(localized: "Layout", bundle: .module), selection: $model.layout.arrangement) {
                ForEach(CombineArrangement.allCases) { arrangement in
                    Label(arrangement.title, systemImage: arrangement.systemImage).tag(arrangement)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if model.layout.arrangement == .grid {
                LabeledStepper(
                    title: String(localized: "Columns", bundle: .module),
                    value: $model.layout.columns,
                    range: CombineLayout.columnsRange
                )
            }
            alignmentRow
        }
    }

    private var alignmentRow: some View {
        HStack {
            Text("Alignment", bundle: .module).font(.system(size: 12))
            Spacer()
            Picker(String(localized: "Alignment", bundle: .module), selection: $model.layout.alignment) {
                ForEach(CombineAlignment.allCases) { alignment in
                    Image(systemName: alignment.systemImage(for: model.layout.arrangement))
                        .help(alignment.title)
                        .accessibilityLabel(alignment.title)
                        .tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var spacingSection: some View {
        InspectorSection(title: String(localized: "Spacing", bundle: .module)) {
            LabeledSlider(
                title: String(localized: "Spacing", bundle: .module),
                value: $model.layout.spacing,
                range: CombineLayout.spacingRange,
                unit: " pt"
            )
            LabeledSlider(
                title: String(localized: "Padding", bundle: .module),
                value: $model.layout.padding,
                range: CombineLayout.paddingRange,
                unit: " pt"
            )
        }
    }

    private var backgroundSection: some View {
        InspectorSection(title: String(localized: "Background", bundle: .module)) {
            Picker(String(localized: "Background", bundle: .module), selection: $model.layout.fillsBackground) {
                Text("Transparent", bundle: .module).tag(false)
                Text("Color", bundle: .module).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if model.layout.fillsBackground {
                HStack {
                    Text("Color", bundle: .module).font(.system(size: 12))
                    Spacer()
                    ColorPicker(String(localized: "Color", bundle: .module), selection: backgroundColor, supportsOpacity: true)
                        .labelsHidden()
                }
            }
        }
    }

    private var imagesSection: some View {
        InspectorSection(title: String(localized: "Images", bundle: .module)) {
            LabeledSlider(
                title: String(localized: "Corner Radius", bundle: .module),
                value: $model.layout.cornerRadius,
                range: CombineLayout.cornerRadiusRange,
                unit: " pt"
            )
            Toggle(isOn: $model.layout.matchSizes) {
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(matchTitle).font(.system(size: 12))
                    Text("Scales smaller images up, at most 2×.", bundle: .module)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var matchTitle: String {
        model.layout.arrangement == .horizontal
            ? String(localized: "Match Heights", bundle: .module)
            : String(localized: "Match Widths", bundle: .module)
    }

    private var backgroundColor: Binding<Color> {
        Binding(
            get: { model.layout.backgroundColor.swiftUIColor },
            set: { model.layout.backgroundColor = CombineColor(color: $0) }
        )
    }
}
