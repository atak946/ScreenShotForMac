import Foundation

/// Tiny local renderer for the filename template preview.
/// The real file naming lives in the export module; this only mirrors it for display.
enum FilenamePreview {
    static var tokens: [(token: String, meaning: String)] {
        [
            ("{date}", "2025-01-31"),
            ("{time}", "14.05.09"),
            ("{app}", String(localized: "Frontmost app name", bundle: .module)),
            ("{counter}", String(localized: "Incrementing number", bundle: .module)),
            ("{timestamp}", String(localized: "Unix time in seconds", bundle: .module)),
        ]
    }

    static func render(_ template: String, date: Date = Date(), appName: String = "Safari", counter: Int = 1) -> String {
        let replacements: [String: String] = [
            "{date}": format(date, "yyyy-MM-dd"),
            "{time}": format(date, "HH.mm.ss"),
            "{app}": appName,
            "{counter}": String(counter),
            "{timestamp}": String(Int(date.timeIntervalSince1970)),
        ]
        let rendered = replacements.reduce(template) { result, pair in
            result.replacingOccurrences(of: pair.key, with: pair.value)
        }
        let trimmed = sanitize(rendered).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Screenshot" : trimmed
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
