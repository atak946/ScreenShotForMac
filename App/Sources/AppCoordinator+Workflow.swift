import AppKit
import ShotBackdrop
import ShotCore
import ShotUpload
import ShotWorkflow

/// Runs workflows and implements the services they need.
extension AppCoordinator: WorkflowEnvironment {
    static let workflowsSettingsPaneID = "workflows"

    // MARK: - Running

    func runWorkflow(id: UUID) {
        guard let workflow = workflowStore.workflow(id: id) else {
            hud.showError(WorkflowError.workflowNotFound(id.uuidString))
            return
        }
        runWorkflow(workflow)
    }

    func runWorkflow(_ reference: WorkflowReference) {
        let workflow: Workflow?
        let label: String
        switch reference {
        case let .id(id):
            workflow = workflowStore.workflow(id: id)
            label = id.uuidString
        case let .name(name):
            workflow = workflowStore.workflow(matching: name)
            label = name
        }
        guard let workflow else {
            hud.showError(WorkflowError.workflowNotFound(label))
            return
        }
        runWorkflow(workflow)
    }

    /// Runs exclusively (no other capture flow meanwhile); progress and errors go to the HUD.
    func runWorkflow(_ workflow: Workflow) {
        guard !workflowRunner.isRunning, !isBusy else {
            hud.showError(WorkflowError.alreadyRunning)
            return
        }
        runExclusive {
            Log.app.info("Running workflow \(workflow.id.uuidString, privacy: .public)")
            await self.workflowRunner.run(workflow) { progress in
                self.report(progress, workflow: workflow)
            }
        }
    }

    private func report(_ progress: WorkflowProgress, workflow: Workflow) {
        switch progress {
        case .capturing:
            break
        case let .step(index, total, step):
            hud.showProgress(String(localized: "\(workflow.name): \(step.title) (\(index + 1)/\(total))"))
        case .finished:
            hud.showHUD(String(localized: "\(workflow.name) finished"))
        case .cancelled:
            Log.app.info("Workflow cancelled")
        case let .failed(_, message):
            hud.showError(WorkflowFailure(message: message))
        }
    }

    // MARK: - WorkflowEnvironment

    func capture(mode: CaptureMode, delay: Int) async throws -> CaptureResult? {
        let result = delay > 0
            ? try await capture.captureDelayed(mode, seconds: delay)
            : try await capture.capture(mode)
        if let result {
            lastCapture = result
            recordInHistory(result)
        }
        return result
    }

    func annotate(_ capture: CaptureResult) async -> CGImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CGImage?, Never>) in
            let gate = ContinuationGate(continuation)
            editor.openEditor(
                for: capture,
                onExport: { image, _ in gate.resume(image) },
                onClose: { gate.resume(nil) }
            )
        }
    }

    func redact(_ image: CGImage) async throws -> CGImage {
        let regions = try await sensitiveDetector.detect(in: image, kinds: Set(SensitiveKind.allCases))
        guard !regions.isEmpty else { return image }
        return ImageRedactor.pixelate(image, regions: regions.map(\.pixelRect)) ?? image
    }

    func backdrop(_ image: CGImage, preset: String) -> CGImage? {
        let name = preset.trimmingCharacters(in: .whitespacesAndNewlines)
        let style: BackdropStyle
        if name.isEmpty {
            style = backdropPresets.lastUsedStyle
        } else if name == BackdropPresetStore.defaultPresetName {
            style = .standard
        } else if let match = backdropPresets.presets.first(where: { $0.name == name }) {
            style = match.style
        } else {
            return nil
        }
        // The protocol passes pixels only; the capture that started the run has the right scale.
        let scale = lastCapture?.scale ?? NSScreen.main?.backingScaleFactor ?? 2
        let background = style.background == .wallpaper ? wallpaper.blurred(radius: style.wallpaperBlur) : nil
        return BackdropRenderer.render(image: image, scale: scale, style: style, wallpaper: background)
    }

    func copy(_ image: CGImage, scale: CGFloat) {
        exporter.copyToClipboard(image, scale: scale)
    }

    func save(_ capture: CaptureResult, to folder: URL?) throws -> URL {
        try exporter.save(capture.image, scale: capture.scale, context: context(for: capture), to: folder)
    }

    func upload(_ capture: CaptureResult) async throws -> URL {
        do {
            return try await uploadAndShare(capture).url
        } catch UploadError.notConfigured {
            showSettings(pane: Self.uploadSettingsPaneID)
            throw UploadError.notConfigured
        }
    }

    func recognizeText(in image: CGImage) async throws -> String {
        try await textRecognizer.recognizeText(in: image, languages: settings.ocrLanguages)
    }

    func copyText(_ text: String) {
        exporter.copyText(text)
    }

    func pin(_ capture: CaptureResult) {
        pins.pin(capture, at: capture.screenRect)
    }

    func quickAccess(_ capture: CaptureResult) {
        quickAccess.show(capture, handlers: quickAccessHandlers(for: capture))
    }

    func notify(_ message: String) {
        hud.showHUD(message)
    }
}

/// Resumes a continuation at most once (export and close can both fire).
@MainActor
private final class ContinuationGate {
    private var continuation: CheckedContinuation<CGImage?, Never>?

    init(_ continuation: CheckedContinuation<CGImage?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: CGImage?) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

/// Wraps a runner failure message so the HUD shows it as an error.
private struct WorkflowFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
