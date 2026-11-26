import Foundation
import KeyboardShortcuts
import Observation
import ShotCore

/// Global hotkey per workflow, stored by KeyboardShortcuts under `workflow.<uuid>`.
/// Keeps registrations in sync with the store (adds, deletes) automatically.
@MainActor
public final class WorkflowHotkeys {
    public typealias Handler = @MainActor (UUID) -> Void

    private let handler: Handler
    private var registered: Set<UUID> = []
    private weak var store: WorkflowStore?

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public static func name(for id: UUID) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("workflow.\(id.uuidString)")
    }

    /// Human-readable shortcut, e.g. "⌃⌥1". Nil when unassigned.
    public static func shortcutDescription(for id: UUID) -> String? {
        name(for: id).shortcut?.description
    }

    /// Registers hotkeys for every workflow in the store and follows later changes.
    public func observe(_ store: WorkflowStore) {
        self.store = store
        track()
    }

    /// Registers handlers for `workflows`, removes handlers (and stored shortcuts) for deleted ones.
    public func sync(with workflows: [Workflow]) {
        let current = Set(workflows.map(\.id))
        for removed in registered.subtracting(current) {
            let name = Self.name(for: removed)
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.reset(name)
        }
        for added in current.subtracting(registered) {
            KeyboardShortcuts.onKeyUp(for: Self.name(for: added)) { [weak self] in
                MainActor.assumeIsolated { self?.handler(added) }
            }
        }
        registered = current
    }

    /// Temporarily disables all workflow hotkeys (e.g. while a menu is open).
    public func setEnabled(_ enabled: Bool) {
        let names = registered.map(Self.name(for:))
        if enabled {
            KeyboardShortcuts.enable(names)
        } else {
            KeyboardShortcuts.disable(names)
        }
    }

    private func track() {
        guard let store else { return }
        let workflows = withObservationTracking {
            store.workflows
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
        sync(with: workflows)
    }
}
