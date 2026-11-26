import AppKit
import ShotCore
import ShotWorkflow

/// Handles `ssfm://` requests (Raycast, Alfred, Shortcuts, App Intents, the `ssfm` CLI).
extension AppCoordinator {
    func handle(_ url: URL) {
        guard let request = AutomationURL.parse(url) else {
            Log.app.error("Ignoring unsupported URL")
            hud.showError(AutomationURLError.unsupported)
            return
        }
        handle(request)
    }

    func handle(_ request: AutomationRequest) {
        switch request {
        case let .capture(mode, action, delay):
            runExclusive {
                let result = delay > 0
                    ? try await self.capture.captureDelayed(mode, seconds: delay)
                    : try await self.capture.capture(mode)
                try self.deliver(result, action: action)
            }
        case .scrollingCapture:
            perform(.captureScrolling)
        case let .record(format):
            toggleRecording(format)
        case let .runWorkflow(reference):
            runWorkflow(reference)
        case let .openFile(url):
            openFileInEditor(url)
        case let .backdropFile(url):
            if let result = loadCapture(from: url) { openBackdrop(result) }
        case let .combineFiles(urls):
            let results = urls.compactMap(loadCapture(from:))
            if results.count == urls.count { showCombine(with: results) }
        case let .command(command):
            perform(command)
        }
    }

    /// Routes a capture to an explicit action; nil follows the "after capture" setting.
    private func deliver(_ result: CaptureResult?, action: AutomationAction?) throws {
        guard let action else { return try deliver(result) }
        guard let result else { return }
        lastCapture = result
        recordInHistory(result)
        switch action {
        case .copy: export(result.image, action: .copy, source: result)
        case .save: export(result.image, action: .save, source: result)
        case .edit: openEditor(result)
        case .upload: uploadCapture(result)
        case .pin: pins.pin(result, at: result.screenRect)
        }
    }

    func openFileInEditor(_ url: URL) {
        if let result = loadCapture(from: url) { openEditor(result) }
    }

    /// Reads an image file as a capture (point size from the file's DPI); shows an error HUD on failure.
    func loadCapture(from url: URL) -> CaptureResult? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            hud.showError(AutomationURLError.unreadableImage(url.lastPathComponent))
            return nil
        }
        let pointWidth = image.size.width > 0 ? image.size.width : CGFloat(cgImage.width)
        let scale = max(1, CGFloat(cgImage.width) / pointWidth)
        let size = CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return CaptureResult(image: cgImage, scale: scale, screenRect: CGRect(origin: .zero, size: size), mode: .area)
    }
}

enum AutomationURLError: LocalizedError {
    case unsupported
    case unreadableImage(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return String(localized: "This ssfm:// link is not supported.")
        case let .unreadableImage(name):
            return String(localized: "“\(name)” could not be opened as an image.")
        }
    }
}
