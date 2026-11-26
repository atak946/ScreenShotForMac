import Foundation
import ShotCore

extension HistoryStore {
    /// Case- and diacritic-insensitive search over OCR text, source app name and the
    /// capture date (several formats). Every whitespace-separated term must match.
    public func search(_ query: String) -> [HistoryItem] {
        HistorySearch.filter(items, query: query)
    }
}

enum HistorySearch {
    @MainActor
    static func filter(_ items: [HistoryItem], query: String) -> [HistoryItem] {
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return items }
        return items.filter { item in
            let haystack = searchableText(for: item)
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    /// Locale-independent folding: with a Turkish locale, `.current` folds "I" to dotless "ı",
    /// so "invoice" would not find "Invoice". Dotless "ı" is also treated as "i" so Turkish
    /// text matches whichever "i" the user types.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "ı", with: "i")
    }

    @MainActor
    private static func searchableText(for item: HistoryItem) -> String {
        let parts = [
            item.recognizedText ?? "",
            item.sourceAppName ?? "",
            item.kind.rawValue,
            longDate.string(from: item.createdAt),
            isoDate.string(from: item.createdAt),
            weekday.string(from: item.createdAt),
        ]
        return normalize(parts.joined(separator: "\n"))
    }

    @MainActor private static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    @MainActor private static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    @MainActor private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMMM"
        return formatter
    }()
}
