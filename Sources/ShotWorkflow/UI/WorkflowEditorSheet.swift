import ShotCore
import SwiftUI

/// Editor for one workflow: name, icon, capture trigger and the ordered step list.
struct WorkflowEditorSheet: View {
    let isNew: Bool
    let backdropPresetNames: [String]
    let onSave: (Workflow) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Workflow
    @State private var steps: [EditableStep]
    @State private var isPickingSymbol = false

    init(workflow: Workflow, isNew: Bool, backdropPresetNames: [String], onSave: @escaping (Workflow) -> Void) {
        self.isNew = isNew
        self.backdropPresetNames = backdropPresetNames
        self.onSave = onSave
        _draft = State(initialValue: workflow)
        _steps = State(initialValue: workflow.steps.map { EditableStep(step: $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                triggerSection
                stepsSection
            }
            .formStyle(.grouped)
            Divider()
            buttonBar
        }
        .frame(width: 520, height: 600)
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            TextField(String(localized: "Name", bundle: .module), text: $draft.name)
            LabeledContent(String(localized: "Icon", bundle: .module)) {
                Button {
                    isPickingSymbol = true
                } label: {
                    WorkflowIcon(symbol: draft.symbol, side: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Choose Icon", bundle: .module))
                .popover(isPresented: $isPickingSymbol, arrowEdge: .trailing) {
                    WorkflowSymbolPicker(selection: $draft.symbol)
                }
            }
        }
    }

    private var triggerSection: some View {
        Section {
            Picker(String(localized: "Capture", bundle: .module), selection: $draft.captureMode) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Label(mode.workflowTitle, systemImage: mode.workflowSymbol).tag(mode)
                }
            }
            Stepper(value: $draft.delaySeconds, in: 0...Workflow.maxDelaySeconds) {
                LabeledContent(String(localized: "Delay", bundle: .module)) {
                    Text(delayText).monospacedDigit()
                }
            }
        } header: {
            Text("Trigger", bundle: .module)
        }
    }

    private var stepsSection: some View {
        Section {
            if steps.isEmpty {
                Text("Add at least one step.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach($steps) { $item in
                WorkflowStepRow(
                    item: $item,
                    backdropPresetNames: backdropPresetNames,
                    onDelete: { remove(item.id) }
                )
            }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { steps.remove(atOffsets: $0) }
        } header: {
            HStack {
                Text("Steps", bundle: .module)
                Spacer()
                addStepMenu
            }
        } footer: {
            WorkflowFooter(text: String(
                localized: "Drag steps to reorder them. Steps after Annotate or Redact use the edited image.",
                bundle: .module
            ))
        }
    }

    private var addStepMenu: some View {
        Menu {
            ForEach(WorkflowStepGroup.allCases) { group in
                Section(group.title) {
                    ForEach(group.kinds) { kind in
                        Button(kind.title, systemImage: kind.systemImage) {
                            steps.append(EditableStep(step: kind.defaultStep))
                        }
                    }
                }
            }
        } label: {
            Label(String(localized: "Add Step", bundle: .module), systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var buttonBar: some View {
        HStack {
            Spacer()
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isNew ? String(localized: "Add", bundle: .module) : String(localized: "Save", bundle: .module)) {
                onSave(finalWorkflow)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(DS.Space.l)
    }

    // MARK: - Helpers

    private var delayText: String {
        draft.delaySeconds == 0
            ? String(localized: "None", bundle: .module)
            : String(localized: "\(draft.delaySeconds) s", bundle: .module)
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && !steps.isEmpty
    }

    private var finalWorkflow: Workflow {
        Workflow(
            id: draft.id,
            name: trimmedName,
            symbol: draft.symbol,
            captureMode: draft.captureMode,
            delaySeconds: draft.delaySeconds,
            steps: steps.map(\.step)
        )
    }

    private func remove(_ id: UUID) {
        steps.removeAll { $0.id == id }
    }
}

/// A step with a stable identity while editing (enum values are not unique).
struct EditableStep: Identifiable, Equatable {
    let id: UUID
    var step: WorkflowStep

    init(id: UUID = UUID(), step: WorkflowStep) {
        self.id = id
        self.step = step
    }
}
