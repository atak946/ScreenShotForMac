import AppKit
import ShotCore
import SwiftUI

/// Right-hand inspector sidebar editing the backdrop style.
struct BackdropInspector: View {
    @Bindable var model: BackdropViewModel
    @State private var isNamingPreset = false
    @State private var presetName = ""

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                presetSection
                Divider().padding(.horizontal, DS.Space.l)
                backgroundSection
                Divider().padding(.horizontal, DS.Space.l)
                layoutSection
                Divider().padding(.horizontal, DS.Space.l)
                shadowSection
                Divider().padding(.horizontal, DS.Space.l)
                canvasSection
            }
            .padding(.vertical, DS.Space.xs)
        }
        .scrollIndicators(.automatic)
        .background(.ultraThinMaterial)
        .alert(String(localized: "Save Preset", bundle: .module), isPresented: $isNamingPreset) {
            TextField(String(localized: "Name", bundle: .module), text: $presetName)
            Button(String(localized: "Save", bundle: .module)) { model.savePreset(named: presetName) }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("Save the current style as a named preset.", bundle: .module)
        }
    }

    // MARK: Sections

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            InspectorHeader(title: String(localized: "Presets", bundle: .module))
                .padding(.horizontal, DS.Space.l)
                .padding(.top, DS.Space.m + DS.Space.xxs)
            BackdropPresetStrip(model: model) {
                presetName = ""
                isNamingPreset = true
            }
            .padding(.bottom, DS.Space.m)
        }
    }

    private var backgroundSection: some View {
        InspectorSection(title: String(localized: "Background", bundle: .module)) {
            Picker(String(localized: "Background", bundle: .module), selection: $model.style.background) {
                ForEach(BackgroundKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            backgroundDetail
        }
    }

    @ViewBuilder private var backgroundDetail: some View {
        switch model.style.background {
        case .none:
            Text("Transparent background", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        case .solid:
            colorRow(String(localized: "Color", bundle: .module), keyPath: \.solidColor)
        case .gradient:
            gradientDetail
        case .wallpaper:
            LabeledSlider(
                title: String(localized: "Blur", bundle: .module),
                value: $model.style.wallpaperBlur,
                range: BackdropStyle.wallpaperBlurRange,
                unit: ""
            )
        }
    }

    private var gradientDetail: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            GradientSwatchGrid(selected: model.style.gradient) { model.applyGradientPreset($0) }
            HStack(spacing: DS.Space.m) {
                ColorPicker(String(localized: "Start", bundle: .module), selection: colorBinding(\.gradient.start), supportsOpacity: true)
                ColorPicker(String(localized: "End", bundle: .module), selection: colorBinding(\.gradient.end), supportsOpacity: true)
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            HStack(spacing: DS.Space.s) {
                Text("Angle", bundle: .module).font(.system(size: 12))
                Spacer()
                Text(verbatim: "\(Int(model.style.gradient.angle.rounded()))°")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                AngleDial(angle: $model.style.gradient.angle)
            }
        }
    }

    private var layoutSection: some View {
        InspectorSection(title: String(localized: "Layout", bundle: .module)) {
            LabeledSlider(
                title: String(localized: "Padding", bundle: .module),
                value: $model.style.padding,
                range: BackdropStyle.paddingRange,
                unit: "pt"
            )
            LabeledSlider(
                title: String(localized: "Corner Radius", bundle: .module),
                value: $model.style.cornerRadius,
                range: BackdropStyle.cornerRadiusRange,
                unit: "pt"
            )
            LabeledSlider(
                title: String(localized: "Scale", bundle: .module),
                value: Binding(
                    get: { model.style.contentScale * 100 },
                    set: { model.style.contentScale = $0 / 100 }
                ),
                range: (BackdropStyle.contentScaleRange.lowerBound * 100)...(BackdropStyle.contentScaleRange.upperBound * 100),
                unit: "%"
            )
        }
    }

    private var shadowSection: some View {
        InspectorSection(title: String(localized: "Shadow", bundle: .module)) {
            Picker(String(localized: "Shadow", bundle: .module), selection: $model.style.shadow) {
                ForEach(ShadowPreset.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var canvasSection: some View {
        InspectorSection(title: String(localized: "Canvas", bundle: .module)) {
            HStack {
                Text("Aspect", bundle: .module).font(.system(size: 12))
                Spacer()
                Picker(String(localized: "Aspect", bundle: .module), selection: $model.style.aspect) {
                    ForEach(AspectPreset.allCases) { preset in
                        Label(preset.title, systemImage: preset.systemImage).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            HStack {
                Text("Alignment", bundle: .module).font(.system(size: 12))
                Spacer()
                Picker(String(localized: "Alignment", bundle: .module), selection: $model.style.alignment) {
                    ForEach(BackdropAlignment.allCases) { alignment in
                        Image(systemName: alignment.systemImage)
                            .accessibilityLabel(alignment.title)
                            .help(alignment.title)
                            .tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .disabled(model.style.aspect == .auto)
        }
    }

    // MARK: Helpers

    private func colorRow(_ title: String, keyPath: WritableKeyPath<BackdropStyle, RGBAColor>) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            ColorPicker(title, selection: colorBinding(keyPath), supportsOpacity: true)
                .labelsHidden()
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<BackdropStyle, RGBAColor>) -> Binding<Color> {
        Binding(
            get: { model.style[keyPath: keyPath].swiftUIColor },
            set: { model.style[keyPath: keyPath] = RGBAColor(color: $0) }
        )
    }
}
