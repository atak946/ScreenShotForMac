import ShotCore
import SwiftUI
import Vision

struct ToolsSettingsTab: View {
    @Bindable var settings: AppSettings
    @State private var availableLanguages: [String] = []
    @State private var loadError: String?
    @State private var isPickingLanguages = false

    var body: some View {
        Form {
            colorSection
            ocrSection
        }
        .formStyle(.grouped)
        .onAppear(perform: loadLanguages)
    }

    private var colorSection: some View {
        Section {
            Picker(String(localized: "Copy colors as", bundle: .module), selection: $settings.colorFormat) {
                ForEach(ColorFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Color Picker", bundle: .module)
        }
    }

    private var ocrSection: some View {
        Section {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            LabeledContent {
                Button(String(localized: "Edit…", bundle: .module)) { isPickingLanguages = true }
                    .popover(isPresented: $isPickingLanguages, arrowEdge: .bottom) {
                        OCRLanguagePicker(available: availableLanguages, selection: $settings.ocrLanguages)
                    }
            } label: {
                Text("Languages", bundle: .module)
            }
            OCRLanguageChips(selection: $settings.ocrLanguages, order: availableLanguages)
        } header: {
            Text("Text Recognition", bundle: .module)
        } footer: {
            SettingsFooter(text: String(
                localized: "Recognition runs on-device. Selected languages are tried in list order; at least one must stay selected.",
                bundle: .module
            ))
        }
    }

    private func loadLanguages() {
        do {
            availableLanguages = try OCRLanguages.supported()
            loadError = nil
        } catch {
            Log.settings.error("Failed to load OCR languages: \(error.localizedDescription, privacy: .public)")
            loadError = String(localized: "Could not load the list of supported languages.", bundle: .module)
            availableLanguages = settings.ocrLanguages
        }
    }
}

enum OCRLanguages {
    static func supported() throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return try request.supportedRecognitionLanguages()
    }

    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    /// Returns a new selection, kept in the supported-language order and never empty.
    static func updated(_ current: [String], toggling code: String, isOn: Bool, order: [String]) -> [String] {
        let next = isOn ? current + [code] : current.filter { $0 != code }
        guard !next.isEmpty else { return current }
        let unique = Array(Set(next))
        return unique.sorted { lhs, rhs in
            (order.firstIndex(of: lhs) ?? Int.max) < (order.firstIndex(of: rhs) ?? Int.max)
        }
    }
}
