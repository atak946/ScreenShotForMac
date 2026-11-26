import Foundation

/// Helpers that reshape OCR output.
public enum TextPostProcessing {
    /// Merges line-broken text into paragraphs. Blank lines separate paragraphs;
    /// words hyphenated across a line break ("exam-\nple") are rejoined.
    public static func joinedIntoParagraph(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let paragraphs = lines.reduce(into: [String]()) { result, line in
            guard !line.isEmpty else {
                if result.last?.isEmpty == false { result.append("") }
                return
            }
            guard let last = result.last, !last.isEmpty else {
                result.append(line)
                return
            }
            result[result.count - 1] = merge(last, line)
        }
        return paragraphs
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func merge(_ current: String, _ next: String) -> String {
        guard isHyphenatedBreak(current, next) else { return current + " " + next }
        return String(current.dropLast()) + next
    }

    private static func isHyphenatedBreak(_ current: String, _ next: String) -> Bool {
        guard current.hasSuffix("-"), current.count >= 2 else { return false }
        let beforeHyphen = current[current.index(current.endIndex, offsetBy: -2)]
        guard beforeHyphen.isLetter, let first = next.first else { return false }
        return first.isLowercase
    }
}
