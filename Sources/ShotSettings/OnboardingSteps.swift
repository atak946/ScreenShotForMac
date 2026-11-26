import ShotCore
import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: DS.Space.l) {
            OnboardingHero(symbol: "camera.viewfinder")
            OnboardingHeading(
                title: String(localized: "Welcome to \(AppInfo.current.name)", bundle: .module),
                subtitle: String(localized: "Everything stays on your Mac. No telemetry.", bundle: .module)
            )
            VStack(alignment: .leading, spacing: DS.Space.m) {
                OnboardingFeatureRow(
                    symbol: "crop",
                    title: String(localized: "Capture anything", bundle: .module),
                    detail: String(localized: "Areas, windows or the full screen with a magnifier for pixel precision.", bundle: .module)
                )
                OnboardingFeatureRow(
                    symbol: "pencil.and.outline",
                    title: String(localized: "Annotate instantly", bundle: .module),
                    detail: String(localized: "Arrows, text, highlights and blur in a fast editor.", bundle: .module)
                )
                OnboardingFeatureRow(
                    symbol: "text.viewfinder",
                    title: String(localized: "Extract text and colors", bundle: .module),
                    detail: String(localized: "On-device OCR, QR scanning and a color picker.", bundle: .module)
                )
            }
            .frame(maxWidth: 400)
        }
    }
}

struct OnboardingPermissionStep: View {
    let request: @MainActor () -> Void
    let isGranted: @MainActor () -> Bool

    @State private var granted = false

    private static let pollInterval: Duration = .seconds(1)

    var body: some View {
        VStack(spacing: DS.Space.l) {
            OnboardingHero(
                symbol: granted ? "checkmark.seal.fill" : "rectangle.dashed.badge.record",
                tint: granted ? .green : .accentColor
            )
            .symbolEffect(.bounce, value: granted)
            OnboardingHeading(
                title: String(localized: "Allow Screen Recording", bundle: .module),
                subtitle: String(localized: """
                macOS requires Screen Recording permission so the app can read the pixels on your screen. \
                Captures never leave your Mac.
                """, bundle: .module)
            )
            statusCard
            Text("After enabling it, macOS may ask you to quit and reopen the app.", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .animation(DS.Motion.spring, value: granted)
        .task { await pollPermission() }
    }

    private var statusCard: some View {
        HStack(spacing: DS.Space.m) {
            SettingsIcon(symbol: "rectangle.dashed.badge.record", color: .indigo, side: 28)
            Text("Screen Recording", bundle: .module)
                .font(.headline)
            Spacer()
            if granted {
                StatusBadge(isGranted: true)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(String(localized: "Open System Settings", bundle: .module)) { SystemSettingsLink.screenRecording.open() }
                    .buttonStyle(.link)
                Button(String(localized: "Grant Permission…", bundle: .module)) { request() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: 420)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(Color.dsStroke))
    }

    private func pollPermission() async {
        granted = isGranted()
        while !Task.isCancelled, !granted {
            try? await Task.sleep(for: Self.pollInterval)
            granted = isGranted()
        }
        if granted { Log.settings.info("Screen Recording permission detected") }
    }
}

struct OnboardingShortcutsStep: View {
    /// The most important hotkeys; the full list lives in Settings › Shortcuts.
    private static let mainCommands: [AppCommand] = [
        .captureArea, .captureWindow, .captureFullscreen, .captureScrolling, .recognizeText, .recordVideo,
    ]

    var body: some View {
        VStack(spacing: DS.Space.l) {
            OnboardingHero(symbol: "keyboard")
            OnboardingHeading(
                title: String(localized: "Your Shortcuts", bundle: .module),
                subtitle: String(localized: "You can change these any time in Settings › Shortcuts.", bundle: .module)
            )
            VStack(spacing: 0) {
                ForEach(Self.mainCommands) { command in
                    HStack {
                        Label(command.title, systemImage: command.systemImage)
                            .labelStyle(OnboardingShortcutLabelStyle())
                        Spacer()
                        ShortcutKeyCaps(shortcut: HotkeyManager.shortcutDescription(for: command))
                    }
                    .padding(.vertical, 5)
                    if command != Self.mainCommands.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.xs)
            .frame(maxWidth: 400)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(Color.dsStroke))
        }
    }
}

private struct OnboardingShortcutLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DS.Space.s) {
            configuration.icon
                .foregroundStyle(.tint)
                .frame(width: 20)
            configuration.title
        }
    }
}
