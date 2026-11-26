import ShotCore
import SwiftUI

/// System Settings–style icon tile + title row (matches ShotSettings panes).
struct UploadRowLabel: View {
    let title: String
    let symbol: String
    let color: Color
    var subtitle: String?

    private static let tileSide: CGFloat = 22

    var body: some View {
        HStack(spacing: DS.Space.s + 2) {
            RoundedRectangle(cornerRadius: Self.tileSide * 0.26, style: .continuous)
                .fill(color.gradient)
                .frame(width: Self.tileSide, height: Self.tileSide)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: Self.tileSide * 0.52, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Self.tileSide * 0.26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: DS.Size.hairline)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Footer text styled like the other settings panes.
struct UploadFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Labeled text field with a placeholder, trimmed input and no autocorrection.
struct UploadTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text, prompt: Text(prompt))
            } else {
                TextField(title, text: $text, prompt: Text(prompt))
                    .autocorrectionDisabled()
            }
        }
        .textContentType(nil)
    }
}
