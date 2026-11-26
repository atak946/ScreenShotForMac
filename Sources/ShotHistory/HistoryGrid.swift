import ShotCore
import SwiftUI

/// Day-grouped adaptive grid with sticky headers, selection and keyboard handling
/// (Space = preview, Return = open, Delete = delete).
struct HistoryGrid: View {
    let model: HistoryBrowserModel
    let sections: [HistorySection]
    @FocusState private var isFocused: Bool

    private static let horizontalInset: CGFloat = 20
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: DS.Space.l)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Space.l + DS.Space.xs) {
                            ForEach(section.items) { item in
                                HistoryGridItem(
                                    item: item,
                                    isThumbnailPending: model.isThumbnailPending(item),
                                    isSelected: model.selectedID == item.id,
                                    model: model,
                                    onSelect: { select(item) }
                                )
                            }
                        }
                        .padding(.horizontal, Self.horizontalInset)
                        .padding(.top, DS.Space.xs)
                        .padding(.bottom, DS.Space.xl)
                    } header: {
                        HistorySectionHeader(section: section, horizontalInset: Self.horizontalInset)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedID = nil }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.space) { handle(model.selectedItem) { _ in model.toggleQuickLook() } }
        .onKeyPress(.return) { handle(model.selectedItem) { model.open($0) } }
        .onKeyPress(.delete) { handle(model.selectedItem) { model.confirmDelete($0) } }
        .onKeyPress(.deleteForward) { handle(model.selectedItem) { model.confirmDelete($0) } }
    }

    private func select(_ item: HistoryItem) {
        model.select(item)
        isFocused = true
    }

    private func handle(_ item: HistoryItem?, action: (HistoryItem) -> Void) -> KeyPress.Result {
        guard let item else { return .ignored }
        action(item)
        return .handled
    }
}

/// Sticky day header: title plus secondary count, on a bar material so tiles scroll beneath.
private struct HistorySectionHeader: View {
    let section: HistorySection
    let horizontalInset: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            Text(section.title)
                .font(.headline)
            Text(verbatim: "\(section.items.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, DS.Space.s + DS.Space.xxs)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
