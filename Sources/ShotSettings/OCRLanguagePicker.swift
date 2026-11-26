import ShotCore
import SwiftUI

/// Selected OCR languages as removable chips. The last remaining chip can't be removed.
struct OCRLanguageChips: View {
    @Binding var selection: [String]
    let order: [String]

    var body: some View {
        FlowLayout {
            ForEach(selection, id: \.self) { code in
                chip(for: code)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(DS.Motion.spring, value: selection)
    }

    private func chip(for code: String) -> some View {
        HStack(spacing: DS.Space.xs) {
            Text(OCRLanguages.displayName(for: code))
                .font(.callout)
            if selection.count > 1 {
                Button {
                    selection = OCRLanguages.updated(selection, toggling: code, isOn: false, order: order)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 14, height: 14)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Remove", bundle: .module))
                .accessibilityLabel(String(localized: "Remove \(OCRLanguages.displayName(for: code))", bundle: .module))
            }
        }
        .padding(.leading, DS.Space.s + 2)
        .padding(.trailing, selection.count > 1 ? DS.Space.xs : DS.Space.s + 2)
        .padding(.vertical, DS.Space.xs)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.25), lineWidth: DS.Size.hairline))
        .help(code)
    }
}

/// Searchable multi-select list of every supported OCR language (fixed size, scrolls).
struct OCRLanguagePicker: View {
    let available: [String]
    @Binding var selection: [String]
    @State private var query = ""

    private static let size = CGSize(width: 300, height: 340)

    var body: some View {
        VStack(spacing: 0) {
            TextField(String(localized: "Search languages", bundle: .module), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(DS.Space.s)
            Divider()
            List(filtered, id: \.self) { code in
                row(for: code)
            }
            .listStyle(.plain)
            .overlay {
                if filtered.isEmpty {
                    Text("No matching languages", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var filtered: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return available }
        return available.filter { code in
            OCRLanguages.displayName(for: code).localizedCaseInsensitiveContains(trimmed)
                || code.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func row(for code: String) -> some View {
        let isSelected = selection.contains(code)
        let isLocked = isSelected && selection.count == 1
        return Button {
            selection = OCRLanguages.updated(selection, toggling: code, isOn: !isSelected, order: available)
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                Text(OCRLanguages.displayName(for: code))
                Spacer()
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}
