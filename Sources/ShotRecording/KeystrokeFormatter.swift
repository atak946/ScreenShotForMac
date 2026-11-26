import AppKit

/// Turns key events into compact `⌘⇧4` style labels.
enum KeystrokeFormatter {
    private static let specialKeys: [UInt16: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// Modifier symbols in the order macOS menus use.
    static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    /// Label for a key-down event, or nil when it should not be shown.
    static func label(keyCode: UInt16, characters: String?, flags: NSEvent.ModifierFlags, shortcutsOnly: Bool) -> String? {
        let relevant = flags.intersection([.control, .option, .shift, .command])
        let special = specialKeys[keyCode]
        let isShortcut = !relevant.isDisjoint(with: [.control, .option, .command])
        if shortcutsOnly, !isShortcut, special == nil { return nil }
        guard let key = special ?? printable(characters) else { return nil }
        return modifierSymbols(relevant) + key
    }

    private static func printable(_ characters: String?) -> String? {
        guard let characters, let first = characters.first, !first.isNewline else { return nil }
        let scalarValue = first.unicodeScalars.first?.value ?? 0
        // Private-use area = function keys without a symbol mapping.
        guard !(0xF700...0xF8FF).contains(scalarValue), !first.isWhitespace else { return nil }
        return String(first).uppercased()
    }
}
