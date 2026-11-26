import ShotCore
import SwiftUI

struct OutputSettingsTab: View {
    @Bindable var settings: AppSettings
    let chooseSaveFolder: @MainActor () -> Void
    let saveFolderPath: @MainActor () -> String

    @State private var folderPath = ""

    var body: some View {
        Form {
            formatSection
            filenameSection
            folderSection
        }
        .formStyle(.grouped)
        .onAppear { folderPath = saveFolderPath() }
        .onChange(of: settings.saveFolderBookmark) { folderPath = saveFolderPath() }
    }

    // MARK: Image

    private var formatSection: some View {
        Section {
            Picker(String(localized: "Format", bundle: .module), selection: $settings.imageFormat) {
                ForEach(ImageFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            if settings.imageFormat.supportsQuality {
                LabeledContent(String(localized: "Quality", bundle: .module)) {
                    HStack(spacing: DS.Space.s) {
                        Slider(value: $settings.imageQuality, in: 0.1...1, step: 0.05)
                            .frame(width: 180)
                        Text(verbatim: "\(Int((settings.imageQuality * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Toggle(String(localized: "Save Retina captures at 1x", bundle: .module), isOn: $settings.downscaleRetina)
        } header: {
            Text("Image", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "PNG is lossless. JPEG and HEIC produce smaller files.", bundle: .module))
        }
    }

    // MARK: File name

    private var filenameSection: some View {
        Section {
            TextField(String(localized: "Template", bundle: .module), text: $settings.filenameTemplate)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
            LabeledContent(String(localized: "Preview", bundle: .module)) {
                Text(previewName)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            LabeledContent(String(localized: "Insert", bundle: .module)) {
                tokenChips
            }
        } header: {
            Text("File Name", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "Click a token to append it to the template. Hover for its meaning.", bundle: .module))
        }
    }

    private var previewName: String {
        "\(FilenamePreview.render(settings.filenameTemplate)).\(settings.imageFormat.fileExtension)"
    }

    private var tokenChips: some View {
        HStack(spacing: DS.Space.xs) {
            ForEach(FilenamePreview.tokens, id: \.token) { item in
                Button(item.token) { settings.filenameTemplate += item.token }
                    .font(.system(.caption, design: .monospaced))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(item.meaning)
            }
        }
    }

    // MARK: Location

    private var folderSection: some View {
        Section {
            LabeledContent {
                Button(String(localized: "Choose…", bundle: .module)) {
                    chooseSaveFolder()
                    folderPath = saveFolderPath()
                }
            } label: {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.tint)
                    Text(folderPath)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(folderPath)
                }
            }
        } header: {
            Text("Save Location", bundle: .module)
        }
    }
}
