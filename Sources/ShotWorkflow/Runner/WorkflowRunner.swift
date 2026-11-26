import AppKit
import CoreGraphics
import Foundation
import ShotCore

/// Executes a workflow: capture, then each step in order, passing the current image along.
/// Stops at the first error and reports progress through a callback.
@MainActor
public final class WorkflowRunner {
    public typealias ProgressHandler = @MainActor (WorkflowProgress) -> Void

    private weak var environment: WorkflowEnvironment?
    public private(set) var isRunning = false

    public init(environment: WorkflowEnvironment) {
        self.environment = environment
    }

    /// Runs the full workflow, starting with its capture.
    @discardableResult
    public func run(_ workflow: Workflow, progress: ProgressHandler? = nil) async -> WorkflowOutcome {
        guard !isRunning else { return fail(nil, WorkflowError.alreadyRunning, progress) }
        guard let environment else { return .cancelled }
        isRunning = true
        defer { isRunning = false }
        progress?(.capturing)
        do {
            guard let capture = try await environment.capture(mode: workflow.captureMode, delay: workflow.delaySeconds) else {
                progress?(.cancelled)
                return .cancelled
            }
            return await execute(workflow.steps, on: capture, environment: environment, progress: progress)
        } catch {
            return fail(nil, error, progress)
        }
    }

    /// Runs only the steps on an existing capture (e.g. an image opened from history).
    @discardableResult
    public func run(steps: [WorkflowStep], on capture: CaptureResult, progress: ProgressHandler? = nil) async -> WorkflowOutcome {
        guard !isRunning else { return fail(nil, WorkflowError.alreadyRunning, progress) }
        guard let environment else { return .cancelled }
        isRunning = true
        defer { isRunning = false }
        return await execute(steps, on: capture, environment: environment, progress: progress)
    }

    // MARK: - Execution

    private func execute(
        _ steps: [WorkflowStep],
        on capture: CaptureResult,
        environment: WorkflowEnvironment,
        progress: ProgressHandler?
    ) async -> WorkflowOutcome {
        var state = WorkflowRunState(capture: capture)
        for (index, step) in steps.enumerated() {
            progress?(.step(index: index, total: steps.count, step: step))
            do {
                guard let next = try await perform(step, state: state, environment: environment) else {
                    progress?(.cancelled)
                    return .cancelled
                }
                state = next
            } catch {
                return fail(index, error, progress)
            }
        }
        progress?(.finished)
        return .completed
    }

    /// Returns the new state, or nil when the user cancelled (e.g. closed the editor).
    private func perform(
        _ step: WorkflowStep,
        state: WorkflowRunState,
        environment: WorkflowEnvironment
    ) async throws -> WorkflowRunState? {
        switch step {
        case .annotateInEditor:
            guard let image = await environment.annotate(state.capture) else { return nil }
            return state.replacingImage(image)
        case .autoRedactSensitive:
            return try await state.replacingImage(environment.redact(state.capture.image))
        case let .applyBackdropPreset(name):
            guard let image = environment.backdrop(state.capture.image, preset: name) else {
                throw WorkflowError.backdropPresetUnavailable(name)
            }
            return state.replacingImage(image)
        case .downscaleTo1x:
            return state.replacingImage(ImageDownscaler.downscaleTo1x(state.capture.image, scale: state.capture.scale), scale: 1)
        default:
            return try await performOutput(step, state: state, environment: environment)
        }
    }

    private func performOutput(
        _ step: WorkflowStep,
        state: WorkflowRunState,
        environment: WorkflowEnvironment
    ) async throws -> WorkflowRunState {
        switch step {
        case .copyImage:
            environment.copy(state.capture.image, scale: state.capture.scale)
            return state
        case let .saveToFolder(bookmark):
            return try state.withFile(save(state, bookmark: bookmark, environment: environment))
        case .upload:
            return try await state.withUploadURL(environment.upload(state.capture))
        case .copyUploadLink:
            guard let link = state.uploadURL else { throw WorkflowError.noUploadLink }
            environment.copyText(link.absoluteString)
            return state
        case .ocrCopyText:
            let text = try await environment.recognizeText(in: state.capture.image)
            guard !text.isEmpty else { throw WorkflowError.noTextFound }
            environment.copyText(text)
            return state
        default:
            return try await performPresentation(step, state: state, environment: environment)
        }
    }

    private func performPresentation(
        _ step: WorkflowStep,
        state: WorkflowRunState,
        environment: WorkflowEnvironment
    ) async throws -> WorkflowRunState {
        switch step {
        case .pin:
            environment.pin(state.capture)
        case .showQuickAccess:
            environment.quickAccess(state.capture)
        case let .openWith(bundleID):
            let file = try state.fileURL ?? TemporaryImageFile.write(state.capture)
            try await ExternalActions.open(file, withBundleID: bundleID)
            return state.withFile(file)
        case let .runShortcut(name):
            let file = try state.fileURL ?? TemporaryImageFile.write(state.capture)
            try await ExternalActions.runShortcut(named: name, input: file)
            return state.withFile(file)
        case .playSound:
            ExternalActions.playCompletionSound()
        default:
            break
        }
        return state
    }

    private func save(_ state: WorkflowRunState, bookmark: Data?, environment: WorkflowEnvironment) throws -> URL {
        guard let bookmark else { return try environment.save(state.capture, to: nil) }
        guard let folder = FolderBookmark.resolve(bookmark) else { throw WorkflowError.folderUnavailable }
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        return try environment.save(state.capture, to: folder)
    }

    private func fail(_ index: Int?, _ error: Error, _ progress: ProgressHandler?) -> WorkflowOutcome {
        let message = error.localizedDescription
        WorkflowLog.logger.error("Workflow failed at step \(index ?? -1): \(message, privacy: .public)")
        progress?(.failed(stepIndex: index, message: message))
        return .failed(stepIndex: index, message: message)
    }
}

/// Immutable state passed between steps.
struct WorkflowRunState {
    let capture: CaptureResult
    var uploadURL: URL?
    var fileURL: URL?

    func replacingImage(_ image: CGImage, scale: CGFloat? = nil) -> WorkflowRunState {
        let updated = CaptureResult(
            image: image,
            scale: scale ?? capture.scale,
            screenRect: capture.screenRect,
            mode: capture.mode,
            capturedAt: capture.capturedAt,
            sourceAppName: capture.sourceAppName
        )
        // The image changed, so a previously written file is stale.
        return WorkflowRunState(capture: updated, uploadURL: uploadURL, fileURL: nil)
    }

    func withUploadURL(_ url: URL) -> WorkflowRunState {
        WorkflowRunState(capture: capture, uploadURL: url, fileURL: fileURL)
    }

    func withFile(_ url: URL) -> WorkflowRunState {
        WorkflowRunState(capture: capture, uploadURL: uploadURL, fileURL: url)
    }
}
