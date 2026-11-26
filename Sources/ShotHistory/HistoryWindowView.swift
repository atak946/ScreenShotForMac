import ShotCore
import SwiftUI

/// Root view of the history window: toolbar (search, filter, ⋯), day-grouped grid, empty states.
struct HistoryWindowView: View {
    static let minimumSize = CGSize(width: 600, height: 420)

    @Bindable var model: HistoryBrowserModel
    let captureShortcut: String

    var body: some View {
        let sections = model.sections
        content(sections)
            .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
            .navigationTitle(Text("Capture History", bundle: .module))
            .navigationSubtitle(Text("\(sections.reduce(0) { $0 + $1.items.count }) items", bundle: .module))
            .searchable(text: $model.query, placement: .toolbar, prompt: Text("Search text, app or date", bundle: .module))
            .toolbar { toolbarContent }
            .sheet(item: $model.quickLookItem) { item in
                HistoryQuickLookView(item: item, model: model)
            }
            .modifier(HistoryDialogs(model: model))
    }

    @ViewBuilder
    private func content(_ sections: [HistorySection]) -> some View {
        if !model.hasAnyItems {
            HistoryEmptyState(shortcut: captureShortcut)
        } else if sections.isEmpty {
            if model.query.isEmpty {
                ContentUnavailableView(model.filter.emptyTitle, systemImage: model.filter.systemImage)
            } else {
                ContentUnavailableView.search(text: model.query)
            }
        } else {
            HistoryGrid(model: model, sections: sections)
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(String(localized: "Filter", bundle: .module), selection: $model.filter) {
                ForEach(HistoryFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(!model.hasAnyItems)
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(String(localized: "Clear All History…", bundle: .module), role: .destructive) {
                    model.isConfirmingClearAll = true
                }
                .disabled(!model.hasAnyItems)
            } label: {
                Label(String(localized: "More", bundle: .module), systemImage: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .help(String(localized: "More", bundle: .module))
        }
    }
}

/// Large symbol, title and a hint with the capture hotkey.
private struct HistoryEmptyState: View {
    let shortcut: String

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, DS.Space.xs)
            Text("No Captures Yet", bundle: .module)
                .font(.title2.weight(.semibold))
            hint
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(DS.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The localized sentence is split around the shortcut so it can be shown as a `KeyCap`
    /// while keeping each language's word order.
    private var hint: some View {
        let sentence = String(localized: "Press \(shortcut) to capture an area.", bundle: .module)
        let parts = sentence.range(of: shortcut).map { (String(sentence[..<$0.lowerBound]), String(sentence[$0.upperBound...])) }
        return HStack(spacing: DS.Space.xs) {
            if let parts {
                Text(parts.0.trimmingCharacters(in: .whitespaces))
                KeyCap(shortcut)
                Text(parts.1.trimmingCharacters(in: .whitespaces))
            } else {
                Text(sentence)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Delete / clear-all confirmations and the error alert.
private struct HistoryDialogs: ViewModifier {
    @Bindable var model: HistoryBrowserModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "Delete this capture?", bundle: .module),
                isPresented: deletionBinding,
                titleVisibility: .visible,
                presenting: model.pendingDeletion
            ) { item in
                Button(String(localized: "Delete", bundle: .module), role: .destructive) { model.delete(item) }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            } message: { _ in
                Text("The file is removed from history permanently.", bundle: .module)
            }
            .confirmationDialog(
                String(localized: "Clear all history?", bundle: .module),
                isPresented: $model.isConfirmingClearAll,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Clear All History", bundle: .module), role: .destructive) { model.clearAll() }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            } message: {
                Text("All captures and recordings stored in history will be deleted. This cannot be undone.", bundle: .module)
            }
            .alert(String(localized: "History Error", bundle: .module), isPresented: errorBinding) {
                Button(String(localized: "OK", bundle: .module), role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { model.pendingDeletion != nil },
            set: { if !$0 { model.pendingDeletion = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
