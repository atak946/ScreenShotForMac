import ShotCore
@testable import ShotTools
import Testing

private func found(_ text: String, kinds: Set<SensitiveKind> = Set(SensitiveKind.allCases)) -> [(SensitiveKind, String)] {
    SensitivePatterns(kinds: kinds).matches(in: text).map { ($0.kind, String(text[$0.range])) }
}

private func kinds(in text: String, only: Set<SensitiveKind> = Set(SensitiveKind.allCases)) -> [SensitiveKind] {
    found(text, kinds: only).map(\.0)
}

@Suite("SensitiveValidators")
struct SensitiveValidatorsTests {
    @Test("Luhn checksum")
    func luhn() {
        #expect(SensitiveValidators.isValidCard("4111 1111 1111 1111"))
        #expect(SensitiveValidators.isValidCard("5500-0000-0000-0004"))
        #expect(!SensitiveValidators.isValidCard("4111 1111 1111 1112"))
        #expect(!SensitiveValidators.isValidCard("0000 0000 0000 0000"), "single repeated digit is rejected")
        #expect(!SensitiveValidators.isValidCard("4111 1111 11"), "too short")
    }

    @Test(
        "Valid IBANs (mod-97)",
        arguments: ["TR33 0006 1005 1978 6457 8413 26", "DE89 3704 0044 0532 0130 00", "GB82WEST12345698765432", "de89370400440532013000"]
    )
    func validIBAN(iban: String) {
        #expect(SensitiveValidators.isValidIBAN(iban))
    }

    @Test(
        "Invalid IBANs",
        arguments: [
            "DE89 3704 0044 0532 0130 01", // checksum
            "TR33 0006 1005 1978 6457 8413", // wrong TR length
            "DE89 3704 0044 0532 0130 0", // wrong DE length
            "TR33-0006-1005-1978-6457-8413-26", // separators
            "XX12", // too short
        ]
    )
    func invalidIBAN(iban: String) {
        #expect(!SensitiveValidators.isValidIBAN(iban))
    }

    @Test("Phone plausibility")
    func phones() {
        #expect(SensitiveValidators.isPlausiblePhone("+90 532 123 45 67"))
        #expect(SensitiveValidators.isPlausiblePhone("(555) 123-4567"))
        #expect(!SensitiveValidators.isPlausiblePhone("123 4567"), "too few digits")
        #expect(!SensitiveValidators.isPlausiblePhone("123.456.789.012"), "dotted quad")
        #expect(!SensitiveValidators.isPlausiblePhone("555--123--4567"), "separator runs")
    }

    @Test("IPv6 validation")
    func ipv6() {
        #expect(SensitiveValidators.isValidIPv6("fe80::1"))
        #expect(SensitiveValidators.isValidIPv6("2001:db8:85a3:0:0:8a2e:370:7334"))
        #expect(!SensitiveValidators.isValidIPv6("12:30:45"))
        #expect(!SensitiveValidators.isValidIPv6("1:2"), "needs at least two colons")
    }

    @Test("Shannon entropy")
    func entropy() {
        #expect(SensitiveValidators.shannonEntropy("") == 0)
        #expect(SensitiveValidators.shannonEntropy("aaaa") == 0)
        #expect(SensitiveValidators.shannonEntropy("abab") == 1)
        #expect(SensitiveValidators.shannonEntropy("abcd") == 2)
    }

    @Test("High-entropy secret heuristic")
    func highEntropy() {
        #expect(SensitiveValidators.isHighEntropySecret("Zq8vK2mP9xL4nR7tW1yB5cD3fG6hJ0sA"))
        #expect(SensitiveValidators.isHighEntropySecret("9f86d081884c7d659a2feaa0c55ad015a3bf4f1b"))
        #expect(!SensitiveValidators.isHighEntropySecret("abcdefghijklmnopqrstuvwxyzabcdefgh"), "no digits")
        #expect(!SensitiveValidators.isHighEntropySecret("12345678901234567890123456789012"), "no letters")
        #expect(!SensitiveValidators.isHighEntropySecret("abcdefgh1234abcdefgh1234abcdefgh"), "no uppercase in base64-like token")
        #expect(!SensitiveValidators.isHighEntropySecret("a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"), "low entropy hex")
    }
}

@Suite("SensitivePatterns")
struct SensitivePatternsTests {
    @Test("Emails are matched without trailing punctuation")
    func emails() {
        let result = found("Contact john.doe+test@example.co.uk, or Jane@Example.COM.", kinds: [.email])
        #expect(result.map(\.1) == ["john.doe+test@example.co.uk", "Jane@Example.COM"])
        #expect(found("not an email: user@localhost", kinds: [.email]).isEmpty)
    }

    @Test("URLs strip trailing punctuation")
    func urls() {
        #expect(found("see (https://example.com/a?b=1).", kinds: [.url]).map(\.1) == ["https://example.com/a?b=1"])
        #expect(found("visit www.example.org!", kinds: [.url]).map(\.1) == ["www.example.org"])
    }

    @Test("Credit cards must pass Luhn")
    func cards() {
        #expect(found("Card: 4111 1111 1111 1111 exp 12/29", kinds: [.creditCard]).map(\.1) == ["4111 1111 1111 1111"])
        #expect(found("Card: 4111 1111 1111 1112", kinds: [.creditCard]).isEmpty)
        #expect(found("Order 1234567890123", kinds: [.creditCard]).isEmpty)
    }

    @Test("IBANs for TR and DE")
    func ibans() {
        #expect(found("IBAN: TR33 0006 1005 1978 6457 8413 26", kinds: [.iban]).map(\.1) == ["TR33 0006 1005 1978 6457 8413 26"])
        #expect(found("Konto DE89370400440532013000.", kinds: [.iban]).map(\.1) == ["DE89370400440532013000"])
        #expect(found("Konto DE89370400440532013001", kinds: [.iban]).isEmpty)
    }

    @Test("IP addresses, including false positives")
    func ipAddresses() {
        #expect(found("server 10.0.0.1 is up", kinds: [.ipAddress]).map(\.1) == ["10.0.0.1"])
        #expect(found("bad 999.1.1.1", kinds: [.ipAddress]).isEmpty)
        #expect(found("version 1.2.3.4.5", kinds: [.ipAddress]).isEmpty)
        #expect(found("link fe80::1 ok", kinds: [.ipAddress]).map(\.1) == ["fe80::1"])
        #expect(found("meeting at 12:30:45", kinds: [.ipAddress]).isEmpty)
    }

    @Test("Phones, including false positives")
    func phones() {
        #expect(found("Call +90 532 123 45 67 today", kinds: [.phone]).map(\.1) == ["+90 532 123 45 67"])
        #expect(found("Tel (555) 123-4567", kinds: [.phone]).map(\.1) == ["(555) 123-4567"])
        #expect(found("Build 123.456.789.012", kinds: [.phone]).isEmpty)
        #expect(found("Year 2024", kinds: [.phone]).isEmpty)
    }

    @Test("JWTs win over the generic API key rule")
    func jwt() {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let result = found("Authorization: Bearer \(token)")
        #expect(result.count == 1)
        #expect(result.first?.0 == .jwt)
        #expect(result.first?.1 == token)
    }

    @Test(
        "Prefixed API keys",
        arguments: SensitiveTestFixtures.prefixedKeys
    )
    func prefixedKeys(key: String) {
        let result = found("key = \(key)", kinds: [.apiKey])
        #expect(result.map(\.1) == [key])
    }

    @Test("Generic tokens need entropy")
    func genericTokens() {
        #expect(kinds(in: "token Zq8vK2mP9xL4nR7tW1yB5cD3fG6hJ0sA end", only: [.apiKey]) == [.apiKey])
        #expect(kinds(in: "path this_is_a_very_long_identifier_name_without_digits", only: [.apiKey]).isEmpty)
        #expect(kinds(in: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", only: [.apiKey]).isEmpty)
    }

    @Test("Only requested kinds are reported and matches do not overlap")
    func kindFiltering() {
        let text = "mail a@b.io from 10.0.0.1 card 4111111111111111"
        #expect(kinds(in: text, only: [.email]) == [.email])
        #expect(Set(kinds(in: text)) == [.email, .ipAddress, .creditCard])
        #expect(found("plain words only").isEmpty)
    }
}

/// Fake tokens are split into concatenated parts so secret scanners don't flag them.
enum SensitiveTestFixtures {
    static let prefixedKeys: [String] = [
        "sk-proj-" + "abcdefghijklmnopqrstuvwxyz123456",
        "sk_live_" + "abcdefghijklmnop1234",
        "ghp_" + "abcdefghijklmnopqrstuvwxyz0123456789",
        "github_pat_" + "11ABCDEFG0123456789_abcdefghijklmnop",
        "xoxb-" + "1234567890-abcdefghij",
        "AKIAIOSFODNN7EXAMPLE",
        "AIza" + "SyA1234567890abcdefghijklmnopqrstuv",
    ]
}
