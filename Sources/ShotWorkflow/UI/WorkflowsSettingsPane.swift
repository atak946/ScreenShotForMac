import KeyboardShortcuts
import ShotCore
import SwiftUI

/// Settings pane listing workflows with their global shortcut, plus add / duplicate / delete.
public struct WorkflowsSettingsPane: View {
    @Bindable private var store: WorkflowStore
    private let backdropPresetNames: [String]
    private let onRun: (@MainActor (Workflow) -> Void)?

    @State private var editing: Workflow?
    @State private var pendingDeletion: Workflow?

    /// - Parameters:
    ///   - backdropPresetNames: saved backdrop preset names, offered in the backdrop step.
    ///   - onRun: optional "Run Now" action shown in each row's menu.
    public init(
        store: WorkflowStore,
        backdropPresetNames: [String] = [],
        onRun: (@MainActor (Workflow) -> Void)? = nil
    ) {
        self.store = store
        self.backdropPresetNames = backdropPresetNames
        self.onRun = onRun
    }

    public var body: some View {
        Form {
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            workflowsSection
            examplesSection
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { workflow in
            WorkflowEditorSheet(
                workflow: workflow,
                isNew: store.workflow(id: workflow.id) == nil,
                backdropPresetNames: backdropPresetNames,
                onSave: save
            )
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { workflow in
            Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                store.delete(id: workflow.id)
            }
        }
    }

    private var workflowsSection: some View {
        Section {
            if store.workflows.isEmpty {
                Text("No workflows yet. Add one to chain a capture with actions like redact, upload and copy link.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.workflows) { workflow in
                WorkflowRow(
                    workflow: workflow,
                    onEdit: { editing = workflow },
                    onDuplicate: { store.duplicate(workflow) },
                    onDelete: { pendingDeletion = workflow },
                    onRun: onRun.map { run in { run(workflow) } }
                )
            }
            .onMove { store.move(fromOffsets: $0, toOffset: $1) }
        } header: {
            HStack {
                Text("Workflows", bundle: .module)
                Spacer()
                Button {
                    editing = Workflow(name: String(localized: "New Workflow", bundle: .module), steps: [.copyImage])
                } label: {
                    Label(String(localized: "Add Workflow", bundle: .module), systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } footer: {
            WorkflowFooter(text: String(
                localized: "Each workflow starts with a capture and runs its steps in order. It stops at the first step that fails. Shortcuts work from any app.",
                bundle: .module
            ))
        }
    }

    private var examplesSection: some View {
        Section {
            LabeledContent(String(localized: "Bring back the example workflows you deleted.", bundle: .module)) {
                Button(String(localized: "Restore Examples", bundle: .module)) { store.restoreExamples() }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var deletionTitle: String {
        guard let pendingDeletion else { return "" }
        return String(localized: "Delete “\(pendingDeletion.name)”?", bundle: .module)
    }

    private func save(_ workflow: Workflow) {
        if store.workflow(id: workflow.id) == nil {
            store.add(workflow)
        } else {
            store.update(workflow)
        }
        editing = nil
    }
}

/// One workflow: icon, name, step summary, shortcut recorder and an actions menu.
struct WorkflowRow: View {
    let workflow: Workflow
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onRun: (() -> Void)?

    var body: some View {
        KeyboardShortcuts.Recorder(for: WorkflowHotkeys.name(for: workflow.id)) {
            HStack(spacing: DS.Space.s) {
                Button(action: onEdit) {
                    WorkflowRowLabel(title: workflow.name, symbol: workflow.symbol, subtitle: summary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Edit Workflow", bundle: .module))
                Spacer(minLength: DS.Space.s)
                actionsMenu
            }
        }
        .contextMenu { menuItems }
    }

    private var actionsMenu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text("Workflow Actions", bundle: .module))
    }

    @ViewBuilder private var menuItems: some View {
        if let onRun {
            Button(String(localized: "Run Now", bundle: .module), systemImage: "play.fill", action: onRun)
            Divider()
        }
        Button(String(localized: "Edit…", bundle: .module), systemImage: "pencil", action: onEdit)
        Button(String(localized: "Duplicate", bundle: .module), systemImage: "plus.square.on.square", action: onDuplicate)
        Divider()
        Button(String(localized: "Delete…", bundle: .module), systemImage: "trash", role: .destructive, action: onDelete)
    }

    private var summary: String {
        let steps = workflow.steps.map(\.title)
        return ([workflow.captureMode.workflowTitle] + steps).joined(separator: " → ")
    }
}
