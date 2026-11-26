import Foundation
import ShotCore

/// A user-defined chain of actions started by one capture (ShareX-style "task").
public struct Workflow: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    /// SF Symbol shown in menus and settings.
    public var symbol: String
    /// What kind of capture starts the workflow.
    public var captureMode: CaptureMode
    /// Countdown before the capture starts, in seconds (0 = immediately).
    public var delaySeconds: Int
    public var steps: [WorkflowStep]

    public static let maxDelaySeconds = 30
    public static let defaultSymbol = "bolt.fill"

    public init(
        id: UUID = UUID(),
        name: String,
        symbol: String = Workflow.defaultSymbol,
        captureMode: CaptureMode = .area,
        delaySeconds: Int = 0,
        steps: [WorkflowStep] = []
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.captureMode = captureMode
        self.delaySeconds = Self.clampDelay(delaySeconds)
        self.steps = steps
    }

    /// Copy with a fresh id and a new name (steps are value types, so they are copied too).
    public func duplicated(named newName: String) -> Workflow {
        Workflow(
            name: newName,
            symbol: symbol,
            captureMode: captureMode,
            delaySeconds: delaySeconds,
            steps: steps
        )
    }

    static func clampDelay(_ value: Int) -> Int {
        min(max(value, 0), maxDelaySeconds)
    }
}

/// One action in a workflow. Steps run in order and receive the current image.
public enum WorkflowStep: Codable, Sendable, Equatable, Hashable {
    case annotateInEditor
    case autoRedactSensitive
    case applyBackdropPreset(name: String)
    case downscaleTo1x
    case copyImage
    /// `bookmark` is a (security-scoped when possible) bookmark of the target folder;
    /// nil means "the configured save folder".
    case saveToFolder(bookmark: Data?)
    case upload
    case copyUploadLink
    case ocrCopyText
    case pin
    case showQuickAccess
    case openWith(appBundleID: String)
    /// Runs a Shortcuts.app shortcut with the image file as input (`shortcuts run`).
    case runShortcut(name: String)
    case playSound

    /// Stable discriminator, used for UI menus and identity.
    public var kind: WorkflowStepKind {
        switch self {
        case .annotateInEditor: return .annotateInEditor
        case .autoRedactSensitive: return .autoRedactSensitive
        case .applyBackdropPreset: return .applyBackdropPreset
        case .downscaleTo1x: return .downscaleTo1x
        case .copyImage: return .copyImage
        case .saveToFolder: return .saveToFolder
        case .upload: return .upload
        case .copyUploadLink: return .copyUploadLink
        case .ocrCopyText: return .ocrCopyText
        case .pin: return .pin
        case .showQuickAccess: return .showQuickAccess
        case .openWith: return .openWith
        case .runShortcut: return .runShortcut
        case .playSound: return .playSound
        }
    }
}

/// Payload-free twin of `WorkflowStep` (for "Add Step" menus).
public enum WorkflowStepKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case annotateInEditor
    case autoRedactSensitive
    case applyBackdropPreset
    case downscaleTo1x
    case copyImage
    case saveToFolder
    case upload
    case copyUploadLink
    case ocrCopyText
    case pin
    case showQuickAccess
    case openWith
    case runShortcut
    case playSound

    public var id: String { rawValue }

    /// A step of this kind with default configuration.
    public var defaultStep: WorkflowStep {
        switch self {
        case .annotateInEditor: return .annotateInEditor
        case .autoRedactSensitive: return .autoRedactSensitive
        case .applyBackdropPreset: return .applyBackdropPreset(name: "")
        case .downscaleTo1x: return .downscaleTo1x
        case .copyImage: return .copyImage
        case .saveToFolder: return .saveToFolder(bookmark: nil)
        case .upload: return .upload
        case .copyUploadLink: return .copyUploadLink
        case .ocrCopyText: return .ocrCopyText
        case .pin: return .pin
        case .showQuickAccess: return .showQuickAccess
        case .openWith: return .openWith(appBundleID: "")
        case .runShortcut: return .runShortcut(name: "")
        case .playSound: return .playSound
        }
    }

    /// Whether the step has inline configuration in the editor.
    public var isConfigurable: Bool {
        switch self {
        case .applyBackdropPreset, .saveToFolder, .openWith, .runShortcut: return true
        default: return false
        }
    }
}
