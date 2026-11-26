import Foundation

/// Builds object names / keys for uploads.
enum ObjectNaming {
    static let randomLength = 10
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    /// Random 10-character name plus the original extension, or the sanitized original name.
    static func objectName(for filename: String, keepOriginal: Bool) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if keepOriginal {
            let sanitized = sanitize(filename)
            if !sanitized.isEmpty { return sanitized }
        }
        var generator = SystemRandomNumberGenerator()
        let random = String((0..<randomLength).map { _ in alphabet.randomElement(using: &generator) ?? "x" })
        return ext.isEmpty ? random : "\(random).\(ext)"
    }

    /// `prefix/name` with `{date}` → `yyyy/MM/dd`, no leading/trailing or duplicate slashes.
    static func key(prefix: String, name: String, date: Date = Date()) -> String {
        let expanded = prefix.replacingOccurrences(of: "{date}", with: datePath(date))
        let parts = expanded.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        return (parts + [name]).joined(separator: "/")
    }

    private static func datePath(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// Keeps letters, digits, `-`, `_`, `.`; spaces become `-`.
    private static func sanitize(_ filename: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = filename.unicodeScalars.map { scalar -> Character in
            if scalar == " " { return "-" }
            return allowed.contains(scalar) && scalar.isASCII ? Character(scalar) : "_"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
