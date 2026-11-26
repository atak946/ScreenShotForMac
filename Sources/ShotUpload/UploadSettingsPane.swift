import ShotCore
import SwiftUI

/// Settings > Upload: destination, credentials, test upload and after-upload behavior.
public struct UploadSettingsPane: View {
    @State private var model = UploadSettingsModel()

    public init() {}

    public var body: some View {
        Form {
            destinationSection
            switch model.preferences.destination {
            case .none:
                EmptyView()
            case .s3:
                S3SettingsSections(model: model)
            case .customHTTP:
                CustomHTTPSettingsSections(model: model)
            }
            if model.preferences.destination != .none {
                UploadTestSection(model: model)
            }
            afterUploadSection
        }
        .formStyle(.grouped)
        .onChange(of: model.preferences.destination) { model.resetTest() }
    }

    private var destinationSection: some View {
        Section {
            Picker(selection: $model.preferences.destination) {
                ForEach(UploadDestinationKind.allCases) { kind in
                    Text(UploadService.displayName(for: kind)).tag(kind)
                }
            } label: {
                UploadRowLabel(
                    title: String(localized: "Destination", bundle: .module),
                    symbol: "icloud.and.arrow.up",
                    color: .blue
                )
            }
            .pickerStyle(.menu)
        } header: {
            Text("Upload", bundle: .module)
        } footer: {
            UploadFooter(text: destinationFooter)
        }
    }

    private var destinationFooter: String {
        switch model.preferences.destination {
        case .none:
            String(localized: "Choose where captures are uploaded when you use Upload.", bundle: .module)
        case .s3:
            String(localized: "Works with AWS S3, Cloudflare R2, MinIO, Backblaze B2 and other S3-compatible storage.", bundle: .module)
        case .customHTTP:
            String(localized: "Send captures to any HTTP endpoint, like a ShareX custom uploader.", bundle: .module)
        }
    }

    private var afterUploadSection: some View {
        Section {
            Toggle(isOn: $model.preferences.copyLinkAfterUpload) {
                UploadRowLabel(title: String(localized: "Copy link to clipboard", bundle: .module), symbol: "link", color: .green)
            }
            Toggle(isOn: $model.preferences.openInBrowserAfterUpload) {
                UploadRowLabel(title: String(localized: "Open link in browser", bundle: .module), symbol: "safari", color: .orange)
            }
            Toggle(isOn: $model.preferences.keepOriginalFilename) {
                UploadRowLabel(
                    title: String(localized: "Keep original file name", bundle: .module),
                    symbol: "doc.text",
                    color: .gray,
                    subtitle: String(localized: "Otherwise a random 10-character name is used.", bundle: .module)
                )
            }
        } header: {
            Text("After Upload", bundle: .module)
        }
    }
}

/// "Test Upload" button with progress and result.
struct UploadTestSection: View {
    let model: UploadSettingsModel

    var body: some View {
        Section {
            LabeledContent {
                HStack(spacing: DS.Space.s) {
                    if model.testState == .running {
                        ProgressView().controlSize(.small)
                    }
                    Button(String(localized: "Test Upload", bundle: .module)) { model.runTest() }
                        .disabled(model.testState == .running)
                }
            } label: {
                UploadRowLabel(
                    title: String(localized: "Connection", bundle: .module),
                    symbol: "network",
                    color: .teal,
                    subtitle: String(localized: "Uploads a tiny 1×1 image to check your settings.", bundle: .module)
                )
            }
            result
        }
    }

    @ViewBuilder private var result: some View {
        switch model.testState {
        case .idle, .running:
            EmptyView()
        case let .succeeded(url):
            HStack(spacing: DS.Space.s) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(nsColor: DS.Palette.success))
                Text(url.absoluteString)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: DS.Space.s)
                Button(String(localized: "Copy Link", bundle: .module)) { model.copy(url) }
            }
            .transition(.opacity)
        case let .failed(message):
            Label {
                Text(message).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(nsColor: DS.Palette.warning))
            }
            .font(.callout)
            .transition(.opacity)
        }
    }
}
