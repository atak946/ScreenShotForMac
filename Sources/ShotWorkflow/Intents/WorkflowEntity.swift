import AppIntents
import Foundation

/// A workflow as seen by Shortcuts.app (picker + "Run Workflow" parameter).
public struct WorkflowEntity: AppEntity, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let symbol: String

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workflow"
    public static let defaultQuery = WorkflowEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    public init(id: UUID, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    init(_ workflow: Workflow) {
        self.init(id: workflow.id, name: workflow.name, symbol: workflow.symbol)
    }
}

/// Reads workflows from the same JSON file as `WorkflowStore`.
public struct WorkflowEntityQuery: EntityStringQuery {
    public init() {}

    @MainActor
    public func entities(for identifiers: [UUID]) async throws -> [WorkflowEntity] {
        let wanted = Set(identifiers)
        return Self.all().filter { wanted.contains($0.id) }
    }

    @MainActor
    public func entities(matching string: String) async throws -> [WorkflowEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return Self.all() }
        return Self.all().filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [WorkflowEntity] {
        Self.all()
    }

    @MainActor
    private static func all() -> [WorkflowEntity] {
        WorkflowStore().workflows.map(WorkflowEntity.init)
    }
}
