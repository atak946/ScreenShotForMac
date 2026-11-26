import Foundation
import ShotCore

/// Regex + validator matching of sensitive values inside one recognized text line.
/// Built per scan (NSRegularExpression instances are not shared across threads).
struct SensitivePatterns {
    struct Match: Equatable {
        let kind: SensitiveKind
        let range: Range<String.Index>
    }

    private struct Rule {
        let kind: SensitiveKind
        let regex: NSRegularExpression
        let validate: (String) -> Bool
    }

    /// Earlier kinds win when matches overlap (e.g. a JWT also looks like a generic key).
    private static let priority: [SensitiveKind] = [.jwt, .apiKey, .email, .url, .iban, .creditCard, .ipAddress, .phone]
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)]}'\"")

    private let rules: [Rule]

    init(kinds: Set<SensitiveKind>) {
        rules = Self.priority.filter(kinds.contains).flatMap(Self.rules(for:))
    }

    /// Non-overlapping matches in `text`.
    func matches(in text: String) -> [Match] {
        var claimed: [Range<String.Index>] = []
        var result: [Match] = []
        let fullRange = NSRange(text.startIndex..., in: text)
        for rule in rules {
            for candidate in rule.regex.matches(in: text, range: fullRange) {
                guard let raw = Range(candidate.range, in: text) else { continue }
                let range = Self.trimmed(raw, in: text)
                guard !range.isEmpty, rule.validate(String(text[range])), !claimed.contains(where: { $0.overlaps(range) }) else { continue }
                claimed.append(range)
                result.append(Match(kind: rule.kind, range: range))
            }
        }
        return result
    }

    private static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var upper = range.upperBound
        while upper > range.lowerBound {
            let previous = text.index(before: upper)
            guard let scalar = text[previous].unicodeScalars.first, trailingPunctuation.contains(scalar) else { break }
            upper = previous
        }
        return range.lowerBound..<upper
    }

    // MARK: - Rules

    private static func rules(for kind: SensitiveKind) -> [Rule] {
        switch kind {
        case .email:
            return rule(kind, #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#)
        case .url:
            return rule(kind, #"\b(?:https?://|www\.)[^\s<>"'`]+"#)
        case .ipAddress:
            let octet = "(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)"
            return rule(kind, "(?<![\\d.])(?:\(octet)\\.){3}\(octet)(?![\\d.])")
                + rule(kind, #"(?<![\w:])(?:[0-9A-F]{0,4}:){2,7}[0-9A-F]{0,4}(?![\w:])"#, SensitiveValidators.isValidIPv6)
        case .creditCard:
            return rule(kind, #"(?<!\d)\d(?:[ \-]?\d){12,18}(?!\d)"#, SensitiveValidators.isValidCard)
        case .iban:
            return rule(kind, #"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}\b"#, SensitiveValidators.isValidIBAN)
        case .phone:
            return rule(kind, #"(?<![\w+])(?:\+|\()?\d[\d \t().\-]{7,22}\d(?!\w)"#, SensitiveValidators.isPlausiblePhone)
        case .apiKey:
            return apiKeyRules()
        case .jwt:
            return rule(kind, #"\beyJ[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}"#, caseInsensitive: false)
        }
    }

    private static func apiKeyRules() -> [Rule] {
        let prefixed = [
            #"\bsk-(?:proj-|live-|test-|ant-)?[A-Za-z0-9_\-]{20,}"#,
            #"\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}"#,
            #"\bgh[pousr]_[A-Za-z0-9]{30,}"#,
            #"\bgithub_pat_[A-Za-z0-9_]{30,}"#,
            #"\bxox[bpars]-[A-Za-z0-9\-]{10,}"#,
            #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#,
            #"\bAIza[0-9A-Za-z_\-]{35}"#,
        ]
        let generic = #"(?<![A-Za-z0-9+/_\-])[A-Za-z0-9+/_\-]{32,}={0,2}(?![A-Za-z0-9+/_\-])"#
        return prefixed.flatMap { rule(.apiKey, $0, caseInsensitive: false) }
            + rule(.apiKey, generic, SensitiveValidators.isHighEntropySecret, caseInsensitive: false)
    }

    private static func rule(
        _ kind: SensitiveKind,
        _ pattern: String,
        _ validate: @escaping (String) -> Bool = { _ in true },
        caseInsensitive: Bool = true
    ) -> [Rule] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
            return [Rule(kind: kind, regex: regex, validate: validate)]
        } catch {
            Log.tools.error("Invalid sensitive-data pattern for \(kind.rawValue, privacy: .public)")
            return []
        }
    }
}
