import ShotCore
import SwiftUI

/// Root layout: mode picker + preview + image strip on the left, inspector on the right.
struct CombineRootView: View {
    static let inspectorWidth: CGFloat = 280
    static let minimumSize = CGSize(width: 820, height: 540)

    @Bindable var model: CombineViewModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                workspace
                Divider()
                ImageStripView(model: model)
            }
            Divider()
            inspector
                .frame(width: Self.inspectorWidth)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .navigationTitle(Text("Combine Images", bundle: .module))
        .navigationSubtitle(subtitle)
        .toolbar { CombineToolbar(model: model) }
        .background { CombineShortcuts(model: model) }
        .onDrop(of: ImageImporter.dropTypes, isTargeted: $model.isDropTargeted) { providers in
            model.handleDrop(providers)
        }
        .overlay { dropHighlight }
    }

    @ViewBuilder private var workspace: some View {
        switch model.mode {
        case .combine: CombinePreviewView(model: model)
        case .split: SplitPreviewView(model: model)
        }
    }

    @ViewBuilder private var inspector: some View {
        switch model.mode {
        case .combine: CombineInspector(model: model)
        case .split: SplitInspector(model: model)
        }
    }

    /// Resolved here: a bridged window subtitle does not look up the module's catalog.
    private var subtitle: String {
        switch model.mode {
        case .combine:
            return String(localized: "\(model.items.count) images", bundle: .module)
        case .split:
            return String(localized: "\(model.sliceRects.count) slices", bundle: .module)
        }
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .padding(DS.Space.xs)
            .opacity(model.isDropTargeted ? 1 : 0)
            .animation(.easeOut(duration: DS.Motion.fast), value: model.isDropTargeted)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Toolbar: Combine | Split segmented control, Copy, and a Save pill with a dropdown.
struct CombineToolbar: ToolbarContent {
    @Bindable var model: CombineViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(String(localized: "Mode", bundle: .module), selection: $model.mode) {
                Text("Combine", bundle: .module).tag(WorkspaceMode.combine)
                Text("Split", bundle: .module).tag(WorkspaceMode.split)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.export(.copy) } label: {
                Label(String(localized: "Copy", bundle: .module), systemImage: "doc.on.doc")
            }
            .help(copyHelp)
            .disabled(!model.canExport)

            HStack(spacing: DS.Space.xxs) {
                Button(saveTitle) { model.export(.save) }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .help(String(localized: "Save (⌘S)", bundle: .module))
                saveMenu
            }
            .disabled(!model.canExport || model.isExporting)
        }
    }

    private var saveMenu: some View {
        Menu {
            if model.mode == .split {
                Button(String(localized: "Save All to Folder…", bundle: .module)) { model.saveAllSlices() }
            } else {
                Button(String(localized: "Save As…", bundle: .module)) { model.export(.saveAs) }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "More Save Options", bundle: .module))
    }

    private var saveTitle: String {
        model.mode == .split
            ? String(localized: "Save Slices", bundle: .module)
            : String(localized: "Save", bundle: .module)
    }

    private var copyHelp: String {
        model.mode == .split
            ? String(localized: "Copy Selected Slice (⌘C)", bundle: .module)
            : String(localized: "Copy to Clipboard (⌘C)", bundle: .module)
    }
}

/// Invisible buttons that own the window's keyboard shortcuts.
private struct CombineShortcuts: View {
    let model: CombineViewModel

    var body: some View {
        ZStack {
            shortcut("c", [.command]) { model.export(.copy) }
            shortcut("s", [.command]) { model.export(.save) }
            shortcut("s", [.command, .shift]) { model.export(.saveAs) }
            shortcut("v", [.command]) { model.pasteImages() }
            shortcut("o", [.command]) { model.addFromPanel() }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func shortcut(_ key: KeyEquivalent, _ modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(.plain)
            .keyboardShortcut(key, modifiers: modifiers)
    }
}
