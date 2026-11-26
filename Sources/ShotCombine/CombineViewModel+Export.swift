import AppKit
import ShotCore

extension CombineViewModel {
    // MARK: Export entry point

    /// Toolbar / shortcut action; routes to Combine or Split depending on the mode.
    func export(_ action: ExportAction) {
        guard !isExporting else { return }
        switch mode {
        case .combine: exportCombined(action)
        case .split: exportSlices(action)
        }
    }

    var canExport: Bool {
        switch mode {
        case .combine: return !items.isEmpty
        case .split: return splitSource != nil
        }
    }

    // MARK: Combine

    private func exportCombined(_ action: ExportAction) {
        let images = sources
        guard !images.isEmpty else {
            NSSound.beep()
            return
        }
        let layout = layout
        isExporting = true
        Task { [weak self] in
            let box = await Task.detached(priority: .userInitiated) {
                CombineRenderer.render(images: images, layout: layout).map(ImageBox.init)
            }.value
            guard let self else { return }
            isExporting = false
            guard let box else {
                Log.editor.error("Combine render failed for export")
                NSSound.beep()
                return
            }
            onExport(box.image, action)
            if action == .save { onRequestClose?() }
        }
    }

    // MARK: Split

    /// Copy = selected slice, Save = every slice through the host, Save As = "Save All…" to a folder.
    private func exportSlices(_ action: ExportAction) {
        guard let source = splitSource?.source else {
            NSSound.beep()
            return
        }
        let slices = SplitRenderer.slices(of: source.image, axis: split.axis, cuts: split.cuts)
        guard !slices.isEmpty else {
            Log.editor.error("Split produced no slices")
            NSSound.beep()
            return
        }
        switch action {
        case .copy:
            onExport(slices[min(selectedSliceIndex, slices.count - 1)], .copy)
        case .save:
            slices.forEach { onExport($0, .save) }
            Log.editor.info("Exported \(slices.count) slices")
        case .saveAs:
            saveAllSlices()
        }
    }

    /// Copies a single slice by index (inspector row action).
    func copySlice(at index: Int) {
        guard let source = splitSource?.source else { return }
        let slices = SplitRenderer.slices(of: source.image, axis: split.axis, cuts: split.cuts)
        guard slices.indices.contains(index) else { return }
        selectedSliceIndex = index
        onExport(slices[index], .copy)
    }

    /// Asks for a folder and writes every slice there as PNG.
    func saveAllSlices() {
        guard let source = splitSource?.source else {
            NSSound.beep()
            return
        }
        let axis = split.axis
        let cuts = split.cuts
        ImageImporter.chooseFolder(for: window) { [weak self] folder in
            self?.writeSlices(of: source, axis: axis, cuts: cuts, to: folder)
        }
    }

    private func writeSlices(of source: CombineImage, axis: SplitAxis, cuts: [Double], to folder: URL) {
        let baseName = Self.sliceBaseName()
        isExporting = true
        Task { [weak self] in
            let written = await Task.detached(priority: .userInitiated) {
                let slices = SplitRenderer.slices(of: source.image, axis: axis, cuts: cuts).map(ImageBox.init)
                return PNGWriter.writeSlices(slices, scale: source.scale, folder: folder, baseName: baseName)
            }.value
            self?.isExporting = false
            Log.editor.info("Wrote \(written) slices to \(folder.path, privacy: .private)")
            if written == 0 {
                NSSound.beep()
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            }
        }
    }

    private static func sliceBaseName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let prefix = String(localized: "Slice", bundle: .module)
        return "\(prefix) \(formatter.string(from: Date()))"
    }

    // MARK: Custom split lines

    /// Adds a custom cut at `fraction`, switching to custom mode (seeded from the equal cuts).
    func addCut(at fraction: Double) {
        var settings = split
        if settings.method == .equal {
            settings.customCuts = settings.cuts
            settings.method = .custom
        }
        settings.customCuts = SplitRenderer.normalizedCuts(settings.customCuts + [fraction])
        split = settings
    }

    func moveCut(at index: Int, to fraction: Double) {
        guard split.method == .custom, split.customCuts.indices.contains(index) else { return }
        split.customCuts[index] = fraction.clamped(to: 0.01...0.99)
    }

    /// Re-sorts cuts after a drag ends.
    func commitCuts() {
        split.customCuts = SplitRenderer.normalizedCuts(split.customCuts)
    }

    func removeCut(at index: Int) {
        guard split.method == .custom, split.customCuts.indices.contains(index) else { return }
        split.customCuts.remove(at: index)
    }

    func setSplitMethod(_ method: SplitMethod) {
        guard method != split.method else { return }
        var settings = split
        if method == .custom, settings.customCuts.isEmpty {
            settings.customCuts = settings.cuts
        }
        settings.method = method
        split = settings
    }
}
