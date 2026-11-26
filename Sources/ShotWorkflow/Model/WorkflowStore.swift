import Foundation
import Observation
import ShotCore

/// Persists workflows as JSON in `~/Library/Application Support/<bundle>/Workflows.json`.
@MainActor
@Observable
public final class WorkflowStore {
    public private(set) var workflows: [Workflow]
    /// Last load / save failure, surfaced in settings.
    public private(set) var lastError: String?

    @ObservationIgnored private let fileURL: URL

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        workflows = []
        load()
    }

    // MARK: - Lookup

    public func workflow(id: UUID) -> Workflow? {
        workflows.first { $0.id == id }
    }

    /// Case-insensitive name match (first wins).
    public func workflow(named name: String) -> Workflow? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return workflows.first { $0.name.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    /// Resolves an id string or a name.
    public func workflow(matching reference: String) -> Workflow? {
        if let id = UUID(uuidString: reference), let match = workflow(id: id) { return match }
        return workflow(named: reference)
    }

    // MARK: - CRUD

    @discardableResult
    public func add(_ workflow: Workflow) -> Workflow {
        workflows += [workflow]
        save()
        return workflow
    }

    public func update(_ workflow: Workflow) {
        guard workflows.contains(where: { $0.id == workflow.id }) else { return }
        workflows = workflows.map { $0.id == workflow.id ? workflow : $0 }
        save()
    }

    @discardableResult
    public func duplicate(_ workflow: Workflow) -> Workflow {
        let suffix = String(localized: "Copy", bundle: .module)
        let copy = workflow.duplicated(named: "\(workflow.name) \(suffix)")
        var updated = workflows
        let index = updated.firstIndex { $0.id == workflow.id }.map { $0 + 1 } ?? updated.count
        updated.insert(copy, at: index)
        workflows = updated
        save()
        return copy
    }

    public func delete(id: UUID) {
        workflows = workflows.filter { $0.id != id }
        save()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = workflows
        updated.move(fromOffsets: source, toOffset: destination)
        workflows = updated
        save()
    }

    /// Re-adds the built-in examples that are missing (matched by id).
    public func restoreExamples() {
        let missing = BuiltInWorkflows.all.filter { example in !workflows.contains { $0.id == example.id } }
        guard !missing.isEmpty else { return }
        workflows += missing
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            workflows = BuiltInWorkflows.all
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            workflows = try JSONDecoder().decode(StoredWorkflows.self, from: data).workflows
            lastError = nil
        } catch {
            WorkflowLog.logger.error("Workflows load failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Could not read saved workflows. Examples were loaded instead.", bundle: .module)
            workflows = BuiltInWorkflows.all
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(StoredWorkflows(version: StoredWorkflows.currentVersion, workflows: workflows))
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            WorkflowLog.logger.error("Workflows save failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Could not save workflows.", bundle: .module)
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let folder = Bundle.main.bundleIdentifier ?? Log.subsystem
        return base.appendingPathComponent(folder, isDirectory: true).appendingPathComponent("Workflows.json")
    }
}

/// On-disk envelope (versioned for future migrations).
private struct StoredWorkflows: Codable {
    static let currentVersion = 1
    let version: Int
    let workflows: [Workflow]
}
