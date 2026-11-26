import ShotCore
import SwiftUI

/// Horizontal strip of preset thumbnails (default + saved) with a trailing "Save preset" tile.
struct BackdropPresetStrip: View {
    let model: BackdropViewModel
    let onSaveRequest: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DS.Space.s + DS.Space.xxs) {
                PresetTile(
                    name: BackdropPresetStore.defaultPresetName,
                    thumbnail: model.thumbnail(for: nil),
                    isSelected: model.selectedPresetID == nil
                ) { model.applyPreset(id: nil) }
                ForEach(model.presets) { preset in
                    PresetTile(
                        name: preset.name,
                        thumbnail: model.thumbnail(for: preset.id),
                        isSelected: model.selectedPresetID == preset.id
                    ) { model.applyPreset(id: preset.id) }
                        .contextMenu {
                            Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                                model.deletePreset(id: preset.id)
                            }
                        }
                }
                SavePresetTile(action: onSaveRequest)
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.xxs)
        }
    }
}

private enum PresetTileMetrics {
    static let size = CGSize(width: 72, height: 50)
    static let radius = DS.Radius.control
}

private struct PresetTile: View {
    let name: String
    let thumbnail: CGImage?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Space.xs) {
                preview
                    .frame(width: PresetTileMetrics.size.width, height: PresetTileMetrics.size.height)
                    .background(Color.dsCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: PresetTileMetrics.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PresetTileMetrics.radius, style: .continuous)
                            .strokeBorder(Color.dsStroke, lineWidth: DS.Size.hairline)
                    )
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: PresetTileMetrics.radius + 3, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                    )
                    .scaleEffect(isHovering && !isSelected ? 1.04 : 1)
                Text(name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: PresetTileMetrics.size.width + 6)
            }
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var preview: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 1)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .transition(.opacity)
        } else {
            ProgressView().controlSize(.mini)
        }
    }
}

private struct SavePresetTile: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Space.xs) {
                RoundedRectangle(cornerRadius: PresetTileMetrics.radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovering ? 0.35 : 0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .background(
                        RoundedRectangle(cornerRadius: PresetTileMetrics.radius, style: .continuous)
                            .fill(Color.primary.opacity(isHovering ? 0.06 : 0.02))
                    )
                    .overlay(Image(systemName: "plus").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary))
                    .frame(width: PresetTileMetrics.size.width, height: PresetTileMetrics.size.height)
                    .padding(3)
                Text("Save Preset", bundle: .module)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: PresetTileMetrics.size.width + 6)
            }
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(String(localized: "Save the current style as a named preset.", bundle: .module))
    }
}
