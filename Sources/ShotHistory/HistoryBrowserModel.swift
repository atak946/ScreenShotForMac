import AppKit
import Foundation
import Observation
import ShotCore

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, images, videos, gifs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "All", bundle: .module)
        case .images: return String(localized: "Images", bundle: .module)
        case .videos: return String(localized: "Videos", bundle: .module)
        case .gifs: return String(localized: "GIFs", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .images: return "photo"
        case .videos: return "video"
        case .gifs: return "photo.stack"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return String(localized: "No Captures", bundle: .module)
        case .images: return String(localized: "No Images", bundle: .module)
        case .videos: return String(localized: "No Videos", bundle: .module)
        case .gifs: return String(localized: "No GIFs", bundle: .module)
        }
    }

    func matches(_ kind: HistoryItem.Kind) -> Bool {
        switch self {
        case .all: return true
        case .images: return kind == .image
        case .videos: return kind == .video
        case .gifs: return kind == .gif
        }
    }
}

struct HistorySection: Identifiable {
    let id: Date
    let title: String
    let items: [HistoryItem]
}

/// State and actions behind the history window.
@MainActor
@Observable
final class HistoryBrowserModel {
    let store: HistoryStore
    var query = ""
    var filter: HistoryFilter = .all
    var pendingDeletion: HistoryItem?
    var selectedID: UUID?
    /// Item shown in the space-bar preview sheet.
    var quickLookItem: HistoryItem?
    var isConfirmingClearAll = false
    var errorMessage: String?
    @ObservationIgnored var onOpen: (@MainActor (CaptureResult) -> Void)?

    init(store: HistoryStore) {
        self.store = store
    }

    var hasAnyItems: Bool { !store.items.isEmpty }

    var sections: [HistorySection] {
        let visible = HistorySearch.filter(store.items, query: query).filter { filter.matches($0.kind) }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            HistorySection(id: day, title: Self.title(for: day, calendar: calendar), items: grouped[day] ?? [])
        }
    }

    var selectedItem: HistoryItem? {
        guard let selectedID else { return nil }
        return store.items.first { $0.id == selectedID }
    }

    func select(_ item: HistoryItem) {
        selectedID = item.id
    }

    /// Toggles the preview sheet for the selected item.
    func toggleQuickLook() {
        if quickLookItem != nil {
            quickLookItem = nil
        } else {
            quickLookItem = selectedItem
        }
    }

    func isThumbnailPending(_ item: HistoryItem) -> Bool {
        store.pendingThumbnailIDs.contains(item.id)
    }

    // MARK: Actions

    func open(_ item: HistoryItem) {
        HistoryItemActions.open(item, store: store, onOpen: onOpen)
    }

    func copy(_ item: HistoryItem) {
        if !HistoryItemActions.copy(item) {
            errorMessage = String(localized: "The file for this capture could not be read.", bundle: .module)
        }
    }

    func reveal(_ item: HistoryItem) {
        HistoryItemActions.reveal(item)
    }

    func dragProvider(for item: HistoryItem) -> NSItemProvider {
        NSItemProvider(contentsOf: item.fileURL) ?? NSItemProvider(object: item.fileURL as NSURL)
    }

    func confirmDelete(_ item: HistoryItem) {
        pendingDeletion = item
    }

    func delete(_ item: HistoryItem) {
        pendingDeletion = nil
        if selectedID == item.id { selectedID = nil }
        if quickLookItem?.id == item.id { quickLookItem = nil }
        ThumbnailCache.shared.evict(item.thumbnailURL)
        perform { try store.remove(item) }
    }

    func clearAll() {
        isConfirmingClearAll = false
        selectedID = nil
        quickLookItem = nil
        store.items.forEach { ThumbnailCache.shared.evict($0.thumbnailURL) }
        perform { try store.removeAll() }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Log.export.error("History action failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private static func title(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return String(localized: "Today", bundle: .module) }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday", bundle: .module) }
        return day.formatted(date: .complete, time: .omitted)
    }
}

/// Item actions shared by the history window and the recent-captures menu.
@MainActor
enum HistoryItemActions {
    /// Images reopen through `onOpen` (editor); videos and GIFs open in their default app.
    static func open(_ item: HistoryItem, store: HistoryStore, onOpen: (@MainActor (CaptureResult) -> Void)?) {
        guard item.kind == .image else {
            NSWorkspace.shared.open(item.fileURL)
            return
        }
        guard let capture = store.loadCapture(item) else {
            Log.export.error("Could not load history capture \(item.id.uuidString, privacy: .public)")
            return
        }
        if let onOpen {
            onOpen(capture)
        } else {
            NSWorkspace.shared.open(item.fileURL)
        }
    }

    /// Images go to the pasteboard as PNG + TIFF; recordings as a file URL.
    @discardableResult
    static func copy(_ item: HistoryItem) -> Bool {
        let pasteboard = NSPasteboard.general
        guard item.kind == .image else {
            pasteboard.clearContents()
            return pasteboard.writeObjects([item.fileURL as NSURL])
        }
        guard let png = try? Data(contentsOf: item.fileURL) else { return false }
        let entry = NSPasteboardItem()
        entry.setData(png, forType: .png)
        if let tiff = NSImage(data: png)?.tiffRepresentation {
            entry.setData(tiff, forType: .tiff)
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([entry])
    }

    static func reveal(_ item: HistoryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }
}
