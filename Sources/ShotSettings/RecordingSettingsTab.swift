import ShotCore
import SwiftUI

struct RecordingSettingsTab: View {
    @Bindable var settings: AppSettings
    var extras: AnyView?
    @State private var microphone = MicrophonePermission()

    private static let videoFPSOptions = [24, 30, 60]
    private static let gifFPSOptions = [10, 15, 20, 30]

    var body: some View {
        Form {
            audioSection
            cursorSection
            frameRateSection
            afterRecordingSection
            if let extras {
                extras
            }
        }
        .formStyle(.grouped)
        .onAppear { microphone.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            microphone.refresh()
        }
    }

    private var audioSection: some View {
        Section {
            Toggle(String(localized: "Record system audio", bundle: .module), isOn: $settings.recordSystemAudio)
            Toggle(String(localized: "Record microphone", bundle: .module), isOn: $settings.recordMicrophone)
            if settings.recordMicrophone {
                microphoneStatusRow
            }
        } header: {
            Text("Audio", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "Audio applies to video recordings only. GIFs are always silent.", bundle: .module))
        }
    }

    private var microphoneStatusRow: some View {
        LabeledContent(String(localized: "Microphone access", bundle: .module)) {
            HStack(spacing: DS.Space.s) {
                if microphone.canRequest {
                    Button(String(localized: "Allow…", bundle: .module)) { Task { await microphone.request() } }
                } else if !microphone.isGranted {
                    Button(String(localized: "Open System Settings", bundle: .module)) { SystemSettingsLink.microphone.open() }
                }
                StatusBadge(isGranted: microphone.isGranted)
            }
        }
    }

    private var cursorSection: some View {
        Section {
            Toggle(String(localized: "Show mouse cursor", bundle: .module), isOn: $settings.recordShowCursor)
            Toggle(String(localized: "Highlight mouse clicks", bundle: .module), isOn: $settings.recordHighlightClicks)
                .disabled(!settings.recordShowCursor)
        } header: {
            Text("Cursor", bundle: .module)
        }
    }

    private var frameRateSection: some View {
        Section {
            fpsPicker(String(localized: "Video", bundle: .module), selection: $settings.recordFramesPerSecond, base: Self.videoFPSOptions)
            fpsPicker(String(localized: "GIF", bundle: .module), selection: $settings.gifFramesPerSecond, base: Self.gifFPSOptions)
        } header: {
            Text("Frame Rate", bundle: .module)
        } footer: {
            SettingsFooter(text: String(localized: "Higher GIF frame rates look smoother but produce much larger files.", bundle: .module))
        }
    }

    private var afterRecordingSection: some View {
        Section {
            Toggle(
                String(localized: "Open trim editor after recording", bundle: .module),
                isOn: $settings.openTrimEditorAfterRecording
            )
        } header: {
            Text("After Recording", bundle: .module)
        } footer: {
            SettingsFooter(text: String(
                localized: "Video recordings open in the trim editor instead of being revealed in Finder.",
                bundle: .module
            ))
        }
    }

    private func fpsPicker(_ title: String, selection: Binding<Int>, base: [Int]) -> some View {
        Picker(title, selection: selection) {
            ForEach(Self.options(base, current: selection.wrappedValue), id: \.self) {
                Text("\($0) fps", bundle: .module).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    /// Keeps an unexpected stored value selectable instead of leaving the picker blank.
    static func options(_ base: [Int], current: Int) -> [Int] {
        base.contains(current) ? base : (base + [current]).sorted()
    }
}
