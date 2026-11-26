import AppKit
import ShotCore
import SwiftUI
import UniformTypeIdentifiers

/// One step in the editor with its inline configuration.
struct WorkflowStepRow: View {
    @Binding var item: EditableStep
    let backdropPresetNames: [String]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                WorkflowRowLabel(title: item.step.title, symbol: item.step.systemImage, color: tint)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Remove Step", bundle: .module))
                .accessibilityLabel(Text("Remove Step", bundle: .module))
            }
            configuration
                .padding(.leading, DS.Space.xl + DS.Space.s)
        }
        .padding(.vertical, DS.Space.xxs)
    }

    private var tint: Color {
        switch item.step.kind.group {
        case .edit: return .orange
        case .output: return .blue
        case .other: return .purple
        }
    }

    @ViewBuilder private var configuration: some View {
        switch item.step {
        case let .applyBackdropPreset(name):
            backdropPicker(current: name)
        case let .saveToFolder(bookmark):
            folderPicker(current: bookmark)
        case let .openWith(bundleID):
            appPicker(current: bundleID)
        case let .runShortcut(name):
            TextField(
                String(localized: "Shortcut name", bundle: .module),
                text: Binding(get: { name }, set: { item.step = .runShortcut(name: $0) }),
                prompt: Text("e.g. Resize for Web", bundle: .module)
            )
            .labelsHidden()
        default:
            EmptyView()
        }
    }

    // MARK: - Pickers

    @ViewBuilder
    private func backdropPicker(current: String) -> some View {
        let binding = Binding(get: { current }, set: { item.step = .applyBackdropPreset(name: $0) })
        if backdropPresetNames.isEmpty {
            TextField(String(localized: "Preset name", bundle: .module), text: binding, prompt: Text("Last used style", bundle: .module))
                .labelsHidden()
        } else {
            Picker(String(localized: "Preset", bundle: .module), selection: binding) {
                Text("Last used style", bundle: .module).tag("")
                ForEach(presetOptions(including: current), id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        }
    }

    private func presetOptions(including current: String) -> [String] {
        guard !current.isEmpty, !backdropPresetNames.contains(current) else { return backdropPresetNames }
        return backdropPresetNames + [current]
    }

    private func folderPicker(current: Data?) -> some View {
        HStack {
            Text(item.step.detail ?? "")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if current != nil {
                Button(String(localized: "Use Default", bundle: .module)) { item.step = .saveToFolder(bookmark: nil) }
            }
            Button(String(localized: "Choose…", bundle: .module), action: chooseFolder)
        }
        .controlSize(.small)
    }

    private func appPicker(current: String) -> some View {
        HStack {
            Text(AppDisplayName.name(forBundleID: current) ?? String(localized: "No app chosen", bundle: .module))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button(String(localized: "Choose App…", bundle: .module), action: chooseApp)
        }
        .controlSize(.small)
    }

    // MARK: - Panels

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose", bundle: .module)
        guard panel.runModal() == .OK, let url = panel.url, let bookmark = FolderBookmark.make(for: url) else { return }
        item.step = .saveToFolder(bookmark: bookmark)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: "Choose", bundle: .module)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            WorkflowLog.logger.error("Chosen app has no bundle identifier")
            return
        }
        item.step = .openWith(appBundleID: bundleID)
    }
}

enum AppDisplayName {
    static func name(forBundleID bundleID: String) -> String? {
        guard !bundleID.isEmpty else { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }
}
