import AppKit
import ShotCore
import ShotExport
import ShotUpload

/// Upload flows: editor / Quick Access buttons and "Upload Last Capture".
extension AppCoordinator {
    static let uploadSettingsPaneID = "upload"

    /// Uploads `capture` as PNG, applies the "after upload" preferences and reports in the HUD.
    func uploadCapture(_ capture: CaptureResult) {
        Task { @MainActor in
            do {
                let result = try await uploadAndShare(capture)
                hud.showHUD(uploadMessage(for: result))
            } catch {
                handleUploadError(error)
            }
        }
    }

    /// Uploads the most recent capture of this session, or the newest image in history.
    func uploadLastCapture() {
        guard let capture = lastCapture ?? latestHistoryCapture() else {
            hud.showHUD(String(localized: "No capture to upload yet"))
            return
        }
        uploadCapture(capture)
    }

    func uploadAndShare(_ capture: CaptureResult) async throws -> UploadResult {
        guard uploader.isConfigured else { throw UploadError.notConfigured }
        let name = exporter.suggestedFilename(context: context(for: capture))
        guard let payload = UploadPayloadFactory.png(capture.image, scale: capture.scale, filename: name) else {
            throw ExportError.encodingFailed(format: "png")
        }
        hud.showProgress(String(localized: "Uploading…"))
        return try await uploader.uploadAndShare(payload)
    }

    func handleUploadError(_ error: Error) {
        if case UploadError.notConfigured = error {
            hud.showError(error)
            showSettings(pane: Self.uploadSettingsPaneID)
            return
        }
        hud.showError(error)
    }

    private func uploadMessage(for result: UploadResult) -> String {
        uploader.preferences.copyLinkAfterUpload
            ? String(localized: "Uploaded to \(result.destinationName). Link copied.")
            : String(localized: "Uploaded to \(result.destinationName)")
    }

    private func latestHistoryCapture() -> CaptureResult? {
        history.recentItems(limit: 20)
            .first { $0.kind == .image }
            .flatMap { history.loadCapture($0) }
    }
}
