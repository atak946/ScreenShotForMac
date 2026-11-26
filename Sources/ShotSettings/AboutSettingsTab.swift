import AppKit
import ShotCore
import SwiftUI

struct AboutSettingsTab: View {
    private let info = AppInfo.current
    private static let acknowledgementsURL = URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")
    private static let developerName = "Murat ATAK"
    private static let developerGitHubURL = URL(string: "https://github.com/atak946")

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .interpolation(.high)
                .frame(width: 104, height: 104)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                .accessibilityHidden(true)
            VStack(spacing: DS.Space.xs) {
                Text(info.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Version \(info.version) (\(info.build))", bundle: .module)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Capture, annotate and share your screen — fast, private and on-device.", bundle: .module)
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Label(String(localized: "All processing happens on your Mac. No telemetry.", bundle: .module), systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
            developerCard
                .padding(.top, DS.Space.s)
            linksRow
            if let copyright = info.copyright {
                Text(copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Space.xxl)
        .padding(.vertical, DS.Space.xxl + DS.Space.s)
    }

    private var developerCard: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text("Developed by \(Self.developerName)", bundle: .module)
                    .font(.headline)
                if let url = Self.developerGitHubURL {
                    Link(destination: url) {
                        Label("github.com/atak946", systemImage: "link")
                    }
                    .font(.callout)
                }
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    private var linksRow: some View {
        HStack(spacing: DS.Space.l) {
            Button {
                SystemSettingsLink.privacy.open()
            } label: {
                Label(String(localized: "Privacy & Security", bundle: .module), systemImage: "hand.raised")
            }
            if let url = Self.acknowledgementsURL {
                Link(destination: url) {
                    Label(String(localized: "Acknowledgements", bundle: .module), systemImage: "heart")
                }
            }
        }
        .buttonStyle(.link)
        .font(.callout)
    }
}

struct AppInfo {
    let name: String
    let version: String
    let build: String
    let copyright: String?

    static var current: AppInfo {
        let bundle = Bundle.main
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ProcessInfo.processInfo.processName
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let copyright = bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        return AppInfo(name: name, version: version, build: build, copyright: copyright)
    }
}
