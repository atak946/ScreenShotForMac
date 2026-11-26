import ShotCore
import SwiftUI

/// Big SF Symbol on a soft accent-gradient tile; the hero of each onboarding step.
struct OnboardingHero: View {
    let symbol: String
    var tint: Color = .accentColor
    var side: CGFloat = 84

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tint.opacity(0.28), tint.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: side * 0.44, weight: .medium))
                    .foregroundStyle(tint.gradient)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .shadow(color: tint.opacity(0.18), radius: 14, y: 6)
            .accessibilityHidden(true)
    }
}

/// Title + subtitle block under the hero.
struct OnboardingHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DS.Space.s) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }
}

/// Icon + title + detail row for the welcome feature list.
struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Page indicator: the current page is a wider accent capsule.
struct OnboardingPageDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .animation(DS.Motion.spring, value: current)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Step \(current + 1) of \(count)", bundle: .module))
    }
}

/// Splits a shortcut description such as "⌥⇧1" into one key cap per key.
struct ShortcutKeyCaps: View {
    let shortcut: String?

    private static let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘", "🌐"]

    var body: some View {
        HStack(spacing: 3) {
            if let shortcut {
                ForEach(Array(Self.keys(in: shortcut).enumerated()), id: \.offset) { _, key in
                    KeyCap(key)
                }
            } else {
                Text(verbatim: "—").foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(shortcut ?? String(localized: "Not set", bundle: .module))
    }

    static func keys(in shortcut: String) -> [String] {
        let modifiers = shortcut.prefix { modifierSymbols.contains($0) }
        let key = shortcut.dropFirst(modifiers.count)
        return modifiers.map { String($0) } + (key.isEmpty ? [] : [String(key)])
    }
}
