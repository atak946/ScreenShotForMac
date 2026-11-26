import Foundation
import ShotCore

/// Renders filenames from templates such as "Screenshot {date} at {time}".
///
/// Supported tokens: `{date}` (yyyy-MM-dd), `{time}` (HH.mm.ss), `{app}`, `{counter}`, `{timestamp}` (unix seconds).
public struct FilenameTemplate: Sendable {
    public static let counterKey = "filenameCounter"
    public static let fallbackName = "Screenshot"

    private static let illegalCharacters = CharacterSet(charactersIn: "/:\\\0")
        .union(.newlines)
        .union(.controlCharacters)
    private static let maxLength = 200

    public init() {}

    /// Renders the template. Pure: does not touch the persisted counter.
    public func render(template: String, context: FilenameContext, counter: Int) -> String {
        let replacements: [(String, String)] = [
            ("{date}", Self.format(context.date, pattern: "yyyy-MM-dd")),
            ("{time}", Self.format(context.date, pattern: "HH.mm.ss")),
            ("{app}", context.appName ?? ""),
            ("{counter}", String(counter)),
            ("{timestamp}", String(Int(context.date.timeIntervalSince1970))),
        ]
        let rendered = replacements.reduce(template) { result, pair in
            result.replacingOccurrences(of: pair.0, with: pair.1)
        }
        return Self.sanitize(rendered)
    }

    /// Returns the next counter value and persists it. Starts at 1.
    public static func nextCounter(defaults: UserDefaults = .standard) -> Int {
        let next = defaults.integer(forKey: counterKey) + 1
        defaults.set(next, forKey: counterKey)
        return next
    }

    /// Whether the template consumes the counter (so we only bump it when used).
    public static func usesCounter(_ template: String) -> Bool {
        template.contains("{counter}")
    }

    static func sanitize(_ name: String) -> String {
        let cleaned = name.unicodeScalars
            .map { illegalCharacters.contains($0) ? "-" : String($0) }
            .joined()
        let collapsed = cleaned
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .-_"))
        let trimmed = String(collapsed.prefix(maxLength))
        // A leading dot would make the file hidden.
        let visible = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        return visible.isEmpty ? fallbackName : visible
    }

    private static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
