import AppKit
import Observation
import ShotCore

/// State of one backdrop composer window.
@MainActor
@Observable
final class BackdropViewModel {
    private static let previewMaxPixels: CGFloat = 1400
    private static let thumbnailMaxPixels: CGFloat = 220

    var style: BackdropStyle {
        didSet { if style != oldValue { schedulePreview() } }
    }

    var selectedPresetID: UUID?
    private(set) var preview: CGImage?
    /// Bumped on every new preview frame; drives the cross-fade.
    private(set) var previewGeneration = 0
    private(set) var presets: [BackdropNamedPreset]
    private var presetThumbnails: [UUID?: CGImage] = [:]

    @ObservationIgnored let capture: CaptureResult
    @ObservationIgnored var onRequestClose: (() -> Void)?
    @ObservationIgnored private let onExport: @MainActor (CGImage, ExportAction) -> Void
    @ObservationIgnored private let store: BackdropPresetStore
    @ObservationIgnored private let wallpaper = WallpaperProvider()
    @ObservationIgnored private let previewSource: ScaledSource
    @ObservationIgnored private let thumbnailSource: ScaledSource
    @ObservationIgnored private var isRendering = false
    @ObservationIgnored private var needsRender = false
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?

    init(capture: CaptureResult, store: BackdropPresetStore, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        self.capture = capture
        self.store = store
        self.onExport = onExport
        style = store.lastUsedStyle
        presets = store.presets
        previewSource = ScaledSource(capture.image, maxPixels: Self.previewMaxPixels)
        thumbnailSource = ScaledSource(capture.image, maxPixels: Self.thumbnailMaxPixels)
        preview = previewJob().render()
        refreshPresetThumbnails()
    }

    /// Final output size in pixels for the current style.
    var outputPixelSize: CGSize {
        BackdropRenderer.layout(
            imageSize: CGSize(width: capture.image.width, height: capture.image.height),
            scale: max(capture.scale, 0.01),
            style: style.sanitized(),
            fixedSizeFactor: 1
        ).canvasSize
    }

    // MARK: Presets

    /// Small rendering of a preset applied to this capture (`nil` id = built-in default).
    func thumbnail(for presetID: UUID?) -> CGImage? {
        presetThumbnails[presetID]
    }

    func applyPreset(id: UUID?) {
        selectedPresetID = id
        guard let id else {
            style = .standard
            return
        }
        if let preset = presets.first(where: { $0.id == id }) {
            style = preset.style
        }
    }

    func savePreset(named name: String) {
        guard let saved = store.save(name: name, style: style) else {
            NSSound.beep()
            return
        }
        presets = store.presets
        selectedPresetID = saved.id
        refreshPresetThumbnails()
    }

    func deletePreset(id: UUID) {
        store.delete(id: id)
        presets = store.presets
        if selectedPresetID == id { selectedPresetID = nil }
        refreshPresetThumbnails()
    }

    func applyGradientPreset(_ preset: GradientPreset) {
        style.gradient = preset.spec
        style.background = .gradient
    }

    // MARK: Export

    func export(_ action: ExportAction) {
        let rendered = BackdropRenderer.render(
            image: capture.image,
            scale: capture.scale,
            style: style,
            wallpaper: wallpaperImage(for: style)
        )
        guard let rendered else {
            Log.editor.error("Backdrop render failed for export")
            NSSound.beep()
            return
        }
        rememberStyle()
        onExport(rendered, action)
        if action == .save {
            onRequestClose?()
        }
    }

    func rememberStyle() {
        store.rememberLastUsed(style)
    }

    // MARK: Preview

    /// Coalesces style changes: at most one background render runs at a time, and the
    /// latest style is rendered as soon as the previous frame lands.
    private func schedulePreview() {
        needsRender = true
        guard !isRendering else { return }
        isRendering = true
        Task { [weak self] in await self?.drainPreviewRenders() }
    }

    private func drainPreviewRenders() async {
        while needsRender {
            needsRender = false
            let image = await previewJob().renderDetached()
            if image == nil {
                Log.editor.error("Backdrop preview render failed")
            }
            preview = image
            previewGeneration &+= 1
        }
        isRendering = false
    }

    private func previewJob() -> BackdropRenderJob {
        job(for: style, source: previewSource)
    }

    private func job(for style: BackdropStyle, source: ScaledSource) -> BackdropRenderJob {
        BackdropRenderJob(
            source: ImageBox(image: source.image),
            scale: max(capture.scale, 0.01) * source.factor,
            style: style,
            wallpaper: wallpaperImage(for: style).map(ImageBox.init),
            fixedSizeFactor: source.factor
        )
    }

    private func refreshPresetThumbnails() {
        let entries: [(UUID?, BackdropStyle)] = [(nil, .standard)] + presets.map { ($0.id, $0.style) }
        let jobs = entries.map { entry in (entry.0, job(for: entry.1, source: thumbnailSource)) }
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            let rendered = await Task.detached(priority: .utility) {
                jobs.compactMap { id, job in job.render().map { (id, ImageBox(image: $0)) } }
            }.value
            guard let self, !Task.isCancelled else { return }
            presetThumbnails = Dictionary(rendered.map { ($0.0, $0.1.image) }) { first, _ in first }
        }
    }

    private func wallpaperImage(for style: BackdropStyle) -> CGImage? {
        style.background == .wallpaper ? wallpaper.blurred(radius: style.wallpaperBlur) : nil
    }
}
