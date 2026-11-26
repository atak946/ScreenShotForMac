import ShotCore
import SwiftUI

/// Toolbar button (eye.slash) that opens the Auto Redact popover.
struct AutoRedactButton: View {
    let viewModel: EditorViewModel
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            if viewModel.isRedacting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "eye.slash")
            }
        }
        .buttonStyle(ToolButtonStyle(isSelected: isPresented))
        .disabled(viewModel.isRedacting)
        .help(String(localized: "Auto Redact", bundle: .module))
        .accessibilityLabel(String(localized: "Auto Redact", bundle: .module))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AutoRedactPopover(viewModel: viewModel) { isPresented = false }
        }
    }
}

/// Style (Blur / Pixelate) + data kinds, then "Redact".
private struct AutoRedactPopover: View {
    private static let width: CGFloat = 240

    let viewModel: EditorViewModel
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text(String(localized: "Auto Redact", bundle: .module))
                .font(.system(size: 13, weight: .semibold))
            Text(String(localized: "Finds sensitive text and hides it.", bundle: .module))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            stylePicker
            Divider()
            kindToggles
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "Redact", bundle: .module)) {
                    dismiss()
                    viewModel.autoRedact()
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.redactOptions.kinds.isEmpty)
            }
        }
        .padding(DS.Space.l)
        .frame(width: Self.width)
    }

    private var stylePicker: some View {
        Picker(
            String(localized: "Style", bundle: .module),
            selection: Binding(get: { viewModel.redactOptions.style }, set: { viewModel.setRedactStyle($0) })
        ) {
            Text(EditorTool.blur.title).tag(EditorTool.blur)
            Text(EditorTool.pixelate.title).tag(EditorTool.pixelate)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var kindToggles: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            ForEach(SensitiveKind.allCases, id: \.self) { kind in
                Toggle(kind.displayName, isOn: Binding(
                    get: { viewModel.redactOptions.kinds.contains(kind) },
                    set: { viewModel.setRedactKind(kind, enabled: $0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
            }
        }
    }
}
