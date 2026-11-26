import AppKit
import ShotCore
import ShotTools

/// OCR, QR, color picker and screen recording flows.
extension AppCoordinator {
    func recognizeText() async throws {
        guard let result = try await capture.capture(.area) else { return }
        let text = try await textRecognizer.recognizeText(in: result.image, languages: settings.ocrLanguages)
        guard !text.isEmpty else {
            hud.showHUD(String(localized: "No text found"))
            return
        }
        exporter.copyText(text)
        hud.showHUD(String(localized: "Copied \(text.count) characters"))
    }

    func scanCodes() async throws {
        guard let result = try await capture.capture(.area) else { return }
        let codes = try await textRecognizer.detectCodes(in: result.image)
        guard let first = codes.first else {
            hud.showHUD(String(localized: "No QR or barcode found"))
            return
        }
        exporter.copyText(codes.joined(separator: "\n"))
        hud.showHUD(
            codes.count == 1
                ? String(localized: "Copied: \(first)")
                : String(localized: "Copied \(codes.count) codes")
        )
    }

    func pickColor() async throws {
        guard let color = try await colorPicker.pickColor() else { return }
        let value = ColorFormatter.string(for: color, format: settings.colorFormat)
        exporter.copyText(value)
        hud.showHUD(String(localized: "Copied \(value)"))
    }

    // MARK: - Recording

    /// Same hotkey starts and stops a recording.
    func toggleRecording(_ format: RecordingFormat) {
        if recorder.isRecording {
            recorder.stop()
            return
        }
        runExclusive {
            let options = self.settings.recordingOptions(format: format)
            guard let recording = try await self.recorder.record(options: options) else { return }
            try self.finishRecording(recording)
        }
    }

    private func finishRecording(_ recording: RecordingResult) throws {
        let (saved, moveError) = moveRecordingToSaveFolder(recording)
        if settings.historyEnabled {
            do {
                try history.addRecording(saved)
            } catch {
                Log.app.error("History add failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        let location = (saved.fileURL.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        if saved.format == .mp4, settings.openTrimEditorAfterRecording {
            videoEditor.open(url: saved.fileURL) { [weak self] edited in
                self?.hud.showHUD(String(localized: "Saved \(edited.lastPathComponent)"))
            }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([saved.fileURL])
        }
        if let moveError {
            hud.showError(moveError)
        } else {
            hud.showHUD(String(localized: "Saved \(saved.fileURL.lastPathComponent) to \(location)"))
        }
    }

    /// Moves the temp recording into the screenshot save folder (unique name, security-scoped
    /// access when a custom folder is set). Keeps the temp file and reports when that fails.
    private func moveRecordingToSaveFolder(_ recording: RecordingResult) -> (RecordingResult, Error?) {
        do {
            let destination = try exporter.moveIntoSaveFolder(recording.fileURL)
            Log.app.info("Recording saved to \(destination.path, privacy: .public)")
            let moved = RecordingResult(
                fileURL: destination,
                format: recording.format,
                duration: recording.duration,
                pixelSize: recording.pixelSize
            )
            return (moved, nil)
        } catch {
            Log.app.error(
                "Could not move recording \(recording.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return (recording, error)
        }
    }
}
