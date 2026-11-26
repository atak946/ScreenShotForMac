import Darwin
import Foundation

/// Checksums and heuristics that turn regex candidates into confident matches.
enum SensitiveValidators {
    private static let ibanMinLength = 15
    private static let ibanMaxLength = 34
    /// Known IBAN lengths for common countries; others fall back to the generic range.
    private static let ibanLengths: [String: Int] = [
        "TR": 26, "DE": 22, "GB": 22, "FR": 27, "NL": 18, "ES": 24, "IT": 27, "BE": 16,
        "AT": 20, "CH": 21, "PL": 28, "SE": 24, "NO": 15, "DK": 18, "FI": 18, "IE": 22, "PT": 25,
    ]
    private static let phoneDigitRange = 10...15
    private static let cardDigitRange = 13...19
    /// Bits per character above which a long token is treated as a secret.
    private static let base64EntropyThreshold = 3.6
    private static let hexEntropyThreshold = 3.0

    static func digits(of text: String) -> String {
        String(text.filter(\.isNumber))
    }

    /// Luhn checksum over the digits of `text` (separators ignored).
    static func isValidCard(_ text: String) -> Bool {
        let digits = digits(of: text).compactMap(\.wholeNumberValue)
        guard cardDigitRange.contains(digits.count), Set(digits).count > 1 else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, pair in
            let (index, digit) = pair
            guard index % 2 == 1 else { return total + digit }
            let doubled = digit * 2
            return total + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }

    /// ISO 13616 mod-97 check, with country length validation for known countries.
    static func isValidIBAN(_ text: String) -> Bool {
        let compact = text.uppercased().filter { !$0.isWhitespace }
        guard (ibanMinLength...ibanMaxLength).contains(compact.count),
              compact.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
        else { return false }
        let country = String(compact.prefix(2))
        if let expected = ibanLengths[country], expected != compact.count { return false }
        let rearranged = compact.dropFirst(4) + compact.prefix(4)
        var remainder = 0
        for character in rearranged {
            guard let value = ibanValue(of: character) else { return false }
            for digit in String(value) {
                remainder = (remainder * 10 + (digit.wholeNumberValue ?? 0)) % 97
            }
        }
        return remainder == 1
    }

    private static func ibanValue(of character: Character) -> Int? {
        if let digit = character.wholeNumberValue { return digit }
        guard let ascii = character.asciiValue, character.isLetter else { return nil }
        return Int(ascii) - Int(Character("A").asciiValue ?? 65) + 10
    }

    /// 10–15 digits, at most one leading "+", no runs of separators.
    static func isPlausiblePhone(_ text: String) -> Bool {
        let count = digits(of: text).count
        guard phoneDigitRange.contains(count), !text.contains("  "), !text.contains("--"), !text.contains("..") else { return false }
        // Version-like / IP-like "1.2.3.4" strings are not phone numbers.
        return !isDottedQuad(text)
    }

    private static func isDottedQuad(_ text: String) -> Bool {
        text.split(separator: ".").count == 4
    }

    static func isValidIPv6(_ text: String) -> Bool {
        guard text.filter({ $0 == ":" }).count >= 2 else { return false }
        var address = in6_addr()
        return text.withCString { inet_pton(AF_INET6, $0, &address) } == 1
    }

    /// High-entropy secret heuristic for generic hex / base64 tokens.
    static func isHighEntropySecret(_ token: String) -> Bool {
        let hasDigit = token.contains(where: \.isNumber)
        let hasLetter = token.contains(where: \.isLetter)
        guard hasDigit, hasLetter else { return false }
        let isHex = token.allSatisfy(\.isHexDigit)
        let threshold = isHex ? hexEntropyThreshold : base64EntropyThreshold
        if !isHex {
            let hasUpper = token.contains(where: \.isUppercase)
            let hasLower = token.contains(where: \.isLowercase)
            guard hasUpper, hasLower else { return false }
        }
        return shannonEntropy(token) >= threshold
    }

    static func shannonEntropy(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let counts = text.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        let length = Double(text.count)
        return counts.values.reduce(0) { entropy, count in
            let probability = Double(count) / length
            return entropy - probability * log2(probability)
        }
    }
}
