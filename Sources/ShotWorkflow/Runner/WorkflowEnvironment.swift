import CoreGraphics
import Foundation
import ShotCore

/// Services a workflow needs. Implemented by the App target (composition root),
/// which forwards each call to the matching module (capture, editor, tools, export, upload…).
@MainActor
public protocol WorkflowEnvironment: AnyObject {
    /// Runs the interactive capture (with countdown when `delay > 0`). Nil = cancelled.
    func capture(mode: CaptureMode, delay: Int) async throws -> CaptureResult?
    /// Opens the editor and waits for the user to finish. Nil = editor closed without exporting.
    func annotate(_ capture: CaptureResult) async -> CGImage?
    /// Detects and pixelates sensitive regions (emails, keys, cards…).
    func redact(_ image: CGImage) async throws -> CGImage
    /// Renders the image with a saved backdrop preset (empty name = last used style).
    /// Nil when the preset does not exist.
    func backdrop(_ image: CGImage, preset: String) -> CGImage?
    func copy(_ image: CGImage, scale: CGFloat)
    /// Saves into `folder` (nil = configured save folder) using the filename template.
    func save(_ capture: CaptureResult, to folder: URL?) throws -> URL
    /// Uploads to the active destination and returns the shareable link.
    func upload(_ capture: CaptureResult) async throws -> URL
    func recognizeText(in image: CGImage) async throws -> String
    func copyText(_ text: String)
    func pin(_ capture: CaptureResult)
    func quickAccess(_ capture: CaptureResult)
    /// Short HUD message.
    func notify(_ message: String)
}

public enum WorkflowError: LocalizedError, Sendable, Equatable {
    case workflowNotFound(String)
    case alreadyRunning
    case backdropPresetUnavailable(String)
    case noUploadLink
    case noTextFound
    case appNotFound(String)
    case shortcutNameMissing
    case shortcutFailed(name: String, status: Int32)
    case folderUnavailable
    case imageEncodingFailed

    public var errorDescription: String? {
        switch self {
        case let .workflowNotFound(reference):
            return String(localized: "No workflow named “\(reference)”.", bundle: .module)
        case .alreadyRunning:
            return String(localized: "Another workflow is already running.", bundle: .module)
        case let .backdropPresetUnavailable(name):
            return String(localized: "Backdrop preset “\(name)” was not found.", bundle: .module)
        case .noUploadLink:
            return String(localized: "There is no upload link to copy. Add an Upload step before it.", bundle: .module)
        case .noTextFound:
            return String(localized: "No text found", bundle: .module)
        case let .appNotFound(bundleID):
            return String(localized: "The app “\(bundleID)” could not be found.", bundle: .module)
        case .shortcutNameMissing:
            return String(localized: "Choose a shortcut name for the Run Shortcut step.", bundle: .module)
        case let .shortcutFailed(name, status):
            return String(localized: "Shortcut “\(name)” failed (exit code \(status)).", bundle: .module)
        case .folderUnavailable:
            return String(localized: "The save folder is no longer available. Choose it again in the workflow.", bundle: .module)
        case .imageEncodingFailed:
            return String(localized: "The image could not be encoded.", bundle: .module)
        }
    }
}

/// Progress events reported by `WorkflowRunner`.
public enum WorkflowProgress: Sendable {
    case capturing
    case step(index: Int, total: Int, step: WorkflowStep)
    case finished
    case cancelled
    case failed(stepIndex: Int?, message: String)
}

/// Final outcome of a run.
public enum WorkflowOutcome: Sendable, Equatable {
    case completed
    case cancelled
    case failed(stepIndex: Int?, message: String)
}
