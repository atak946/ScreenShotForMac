import ShotCore
import SwiftUI

/// System Settings–style icon tile (matches `SettingsIcon` in ShotSettings).
struct WorkflowIcon: View {
    let symbol: String
    var color: Color = .indigo
    var side: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
            .fill(color.gradient)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: side * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.monochrome)
            }
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: DS.Size.hairline)
            )
            .accessibilityHidden(true)
    }
}

struct WorkflowRowLabel: View {
    let title: String
    let symbol: String
    var color: Color = .indigo
    var subtitle: String?

    var body: some View {
        HStack(spacing: DS.Space.s + 2) {
            WorkflowIcon(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct WorkflowFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small grid of SF Symbols for the workflow icon.
struct WorkflowSymbolPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    static let symbols = [
        "bolt.fill", "camera.viewfinder", "crop", "macwindow", "display", "rectangle.dashed",
        "icloud.and.arrow.up", "link", "doc.on.doc", "folder", "tray.and.arrow.down", "paperplane",
        "eye.slash", "lock.shield", "pencil.tip.crop.circle", "wand.and.stars", "sparkles", "text.viewfinder",
        "pin", "star", "flag", "tag", "briefcase", "ant",
    ]

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: DS.Space.xs), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Space.xs) {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                    dismiss()
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: DS.Size.symbolPointSize, weight: .medium))
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                                .fill(symbol == selection ? Color.accentColor.opacity(0.22) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(symbol))
                .accessibilityAddTraits(symbol == selection ? .isSelected : [])
            }
        }
        .padding(DS.Space.m)
    }
}
