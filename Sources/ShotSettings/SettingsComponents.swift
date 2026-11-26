import ShotCore
import SwiftUI

/// System Settings–style rounded icon tile (white symbol on a tinted gradient).
struct SettingsIcon: View {
    let symbol: String
    let color: Color
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

/// Row label: icon tile, title and an optional secondary line.
struct SettingsRowLabel: View {
    let title: String
    let symbol: String
    let color: Color
    var subtitle: String?

    var body: some View {
        HStack(spacing: DS.Space.s + 2) {
            SettingsIcon(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Capsule status badge: green check when granted, orange warning when missing.
struct StatusBadge: View {
    let isGranted: Bool

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .contentTransition(.symbolEffect(.replace))
            Text(isGranted ? String(localized: "Granted", bundle: .module) : String(localized: "Not granted", bundle: .module))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, DS.Space.s)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .animation(DS.Motion.spring, value: isGranted)
    }

    private var tint: Color {
        Color(nsColor: isGranted ? DS.Palette.success : DS.Palette.warning)
    }
}

/// Footer text styled consistently across panes.
struct SettingsFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Space.xs + 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let current = rows[rows.count - 1]
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if projected > maxWidth, !current.indices.isEmpty {
                rows.append(Row(indices: [index], y: current.y + current.height + spacing, width: size.width, height: size.height))
            } else {
                rows[rows.count - 1] = Row(
                    indices: current.indices + [index],
                    y: current.y,
                    width: projected,
                    height: max(current.height, size.height)
                )
            }
        }
        return rows
    }
}
