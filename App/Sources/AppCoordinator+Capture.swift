import AppKit
import ShotCore

/// Post-capture routing: history, clipboard, Quick Access, editor, export.
extension AppCoordinator {
    func deliver(_ result: CaptureResult?) throws {
        guard let result else { return }
        lastCapture = result
        recordInHistory(result)
        if let quickAction = result.quickAction {
            // Copy / Save picked in the capture overlay: do just that, skip the preview.
            export(result.image, action: quickAction, source: result)
            return
        }
        if settings.alsoCopyToClipboard || settings.afterCapture == .copyToClipboard {
            exporter.copyToClipboard(result.image, scale: result.scale)
        }
        switch settings.afterCapture {
        case .showQuickAccess:
            quickAccess.show(result, handlers: quickAccessHandlers(for: result))
        case .openEditor:
            openEditor(result)
        case .copyToClipboard:
            hud.showHUD(String(localized: "Copied to clipboard"))
        case .saveToFile:
            let url = try exporter.save(result.image, scale: result.scale, context: context(for: result))
            hud.showHUD(String(localized: "Saved \(url.lastPathComponent)"))
        }
    }

    func openEditor(_ result: CaptureResult) {
        editor.openEditor(for: result) { [weak self] image, action in
            self?.export(image, action: action, source: result)
        }
    }

    func openBackdrop(_ result: CaptureResult) {
        backdrop.openBackdrop(for: result) { [weak self] image, action in
            self?.export(image, action: action, source: result)
        }
    }

    func export(_ image: CGImage, action: ExportAction, source: CaptureResult) {
        do {
            switch action {
            case .copy:
                exporter.copyToClipboard(image, scale: source.scale)
                hud.showHUD(String(localized: "Copied to clipboard"))
            case .save:
                let url = try exporter.save(image, scale: source.scale, context: context(for: source))
                hud.showHUD(String(localized: "Saved \(url.lastPathComponent)"))
            case .saveAs:
                if let url = try exporter.saveAs(image, scale: source.scale, context: context(for: source)) {
                    hud.showHUD(String(localized: "Saved \(url.lastPathComponent)"))
                }
            }
        } catch {
            hud.showError(error)
        }
    }

    func context(for result: CaptureResult) -> FilenameContext {
        FilenameContext(date: result.capturedAt, appName: result.sourceAppName)
    }

    func quickAccessHandlers(for result: CaptureResult) -> QuickAccessHandlers {
        QuickAccessHandlers(
            onEdit: { [weak self] in self?.openEditor(result) },
            onCopy: { [weak self] in
                self?.exporter.copyToClipboard(result.image, scale: result.scale)
                self?.hud.showHUD(String(localized: "Copied to clipboard"))
            },
            onSave: { [weak self] in self?.export(result.image, action: .save, source: result) },
            onPin: { [weak self] in self?.pins.pin(result, at: result.screenRect) },
            onUpload: { [weak self] in self?.uploadCapture(result) }
        )
    }

    func recordInHistory(_ result: CaptureResult) {
        guard settings.historyEnabled else { return }
        do {
            try history.add(result)
        } catch {
            Log.app.error("History add failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Clipboard

    func pinFromClipboard() {
        guard let result = Self.captureFromClipboard() else {
            hud.showHUD(String(localized: "No image on the clipboard"))
            return
        }
        pins.pin(result, at: nil)
    }

    func openFromClipboard() {
        guard let result = Self.captureFromClipboard() else {
            hud.showHUD(String(localized: "No image on the clipboard"))
            return
        }
        openEditor(result)
    }

    /// Builds a capture from the first image on the general pasteboard.
    static func captureFromClipboard() -> CaptureResult? {
        guard
            let image = NSImage(pasteboard: .general),
            let rep = image.representations.first,
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let pointWidth = image.size.width > 0 ? image.size.width : CGFloat(rep.pixelsWide)
        let scale = max(1, CGFloat(cgImage.width) / pointWidth)
        let size = CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return CaptureResult(image: cgImage, scale: scale, screenRect: CGRect(origin: .zero, size: size), mode: .area)
    }
}
