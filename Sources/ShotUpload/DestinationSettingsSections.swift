import ShotCore
import SwiftUI

/// S3-compatible storage fields.
struct S3SettingsSections: View {
    @Bindable var model: UploadSettingsModel

    var body: some View {
        Section {
            UploadTextField(
                title: String(localized: "Endpoint URL", bundle: .module),
                prompt: "https://s3.us-east-1.amazonaws.com",
                text: $model.s3.endpoint
            )
            UploadTextField(title: String(localized: "Region", bundle: .module), prompt: "us-east-1", text: $model.s3.region)
            UploadTextField(title: String(localized: "Bucket", bundle: .module), prompt: "my-screenshots", text: $model.s3.bucket)
            Toggle(String(localized: "Use path-style URLs", bundle: .module), isOn: $model.s3.usePathStyle)
        } header: {
            Text("Storage", bundle: .module)
        } footer: {
            UploadFooter(text: String(
                localized: "Cloudflare R2 uses the region \"auto\". MinIO usually needs path-style URLs.",
                bundle: .module
            ))
        }
        Section {
            UploadTextField(title: String(localized: "Access Key ID", bundle: .module), prompt: "AKIA…", text: $model.s3.accessKeyID)
            UploadTextField(
                title: String(localized: "Secret Access Key", bundle: .module),
                prompt: String(localized: "Required", bundle: .module),
                text: $model.s3Secret,
                isSecure: true
            )
        } header: {
            Text("Credentials", bundle: .module)
        } footer: {
            UploadFooter(text: String(localized: "The secret access key is stored in your Keychain.", bundle: .module))
        }
        Section {
            UploadTextField(
                title: String(localized: "Path prefix", bundle: .module),
                prompt: "screenshots/{date}",
                text: $model.s3.pathPrefix
            )
            UploadTextField(
                title: String(localized: "Public URL", bundle: .module),
                prompt: "https://cdn.example.com",
                text: $model.s3.publicBaseURL
            )
            Toggle(String(localized: "Make uploads public (public-read ACL)", bundle: .module), isOn: $model.s3.publicReadACL)
        } header: {
            Text("Links", bundle: .module)
        } footer: {
            UploadFooter(text: String(
                localized: "{date} becomes year/month/day. Set a public URL to share links through a custom domain or CDN; leave it empty to use the bucket URL.",
                bundle: .module
            ))
        }
    }
}

/// ShareX-style custom HTTP uploader fields.
struct CustomHTTPSettingsSections: View {
    @Bindable var model: UploadSettingsModel

    var body: some View {
        Section {
            Picker(String(localized: "Method", bundle: .module), selection: $model.customHTTP.method) {
                ForEach(CustomHTTPMethod.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            }
            UploadTextField(
                title: String(localized: "Request URL", bundle: .module),
                prompt: "https://example.com/upload",
                text: $model.customHTTP.url
            )
            Picker(String(localized: "Body", bundle: .module), selection: $model.customHTTP.body) {
                Text("Multipart form data", bundle: .module).tag(CustomHTTPBody.multipart)
                Text("Binary (raw file)", bundle: .module).tag(CustomHTTPBody.binary)
            }
            if model.customHTTP.body == .multipart {
                UploadTextField(
                    title: String(localized: "File field name", bundle: .module),
                    prompt: "file",
                    text: $model.customHTTP.fileFieldName
                )
            }
        } header: {
            Text("Request", bundle: .module)
        }
        HeadersSection(model: model)
        responseSection
    }

    private var responseSection: some View {
        Section {
            Picker(String(localized: "Link from", bundle: .module), selection: $model.customHTTP.urlSource) {
                Text("JSON key path", bundle: .module).tag(ResponseURLSource.jsonPath)
                Text("Regular expression", bundle: .module).tag(ResponseURLSource.regex)
                Text("Location header", bundle: .module).tag(ResponseURLSource.locationHeader)
            }
            switch model.customHTTP.urlSource {
            case .jsonPath:
                UploadTextField(
                    title: String(localized: "JSON key path", bundle: .module),
                    prompt: "data.link",
                    text: $model.customHTTP.urlExpression
                )
            case .regex:
                UploadTextField(
                    title: String(localized: "Regular expression", bundle: .module),
                    prompt: "\"url\":\"([^\"]+)\"",
                    text: $model.customHTTP.urlExpression
                )
            case .locationHeader:
                EmptyView()
            }
        } header: {
            Text("Response", bundle: .module)
        } footer: {
            UploadFooter(text: String(
                localized: "Use dots for nested keys and numbers for array items, e.g. files.0.url. A regular expression returns its first capture group.",
                bundle: .module
            ))
        }
    }
}

/// Editable header list; secret values go to the Keychain.
private struct HeadersSection: View {
    @Bindable var model: UploadSettingsModel

    var body: some View {
        Section {
            ForEach($model.customHTTP.headers) { $header in
                HStack(spacing: DS.Space.s) {
                    TextField(String(localized: "Name", bundle: .module), text: $header.name, prompt: Text(verbatim: "Authorization"))
                        .labelsHidden()
                        .autocorrectionDisabled()
                    valueField(for: $header)
                    Toggle(String(localized: "Secret", bundle: .module), isOn: secretBinding(for: header.id, current: header.isSecret))
                        .toggleStyle(.checkbox)
                    Button {
                        model.removeHeader(header.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(ToolButtonStyle())
                    .help(String(localized: "Remove header", bundle: .module))
                    .accessibilityLabel(String(localized: "Remove header", bundle: .module))
                }
            }
            Button(String(localized: "Add Header", bundle: .module), systemImage: "plus") { model.addHeader() }
        } header: {
            Text("Headers", bundle: .module)
        } footer: {
            UploadFooter(text: String(localized: "Values marked Secret are stored in your Keychain.", bundle: .module))
        }
    }

    @ViewBuilder
    private func valueField(for header: Binding<UploadHeader>) -> some View {
        let valuePrompt = Text("Value", bundle: .module)
        if header.wrappedValue.isSecret {
            let id = header.wrappedValue.id
            SecureField(
                String(localized: "Value", bundle: .module),
                text: Binding(get: { model.headerSecret(for: id) }, set: { model.setHeaderSecret($0, for: id) }),
                prompt: valuePrompt
            )
            .labelsHidden()
        } else {
            TextField(String(localized: "Value", bundle: .module), text: header.value, prompt: valuePrompt)
                .labelsHidden()
                .autocorrectionDisabled()
        }
    }

    private func secretBinding(for id: UUID, current: Bool) -> Binding<Bool> {
        Binding(get: { current }, set: { model.setHeaderSecret(isSecret: $0, for: id) })
    }
}
