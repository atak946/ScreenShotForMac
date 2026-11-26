import AppKit
import Observation
import ShotCore

/// Top-level mode of the window.
enum WorkspaceMode: String, CaseIterable, Identifiable {
    case combine
    case split

    var id: String { rawValue }
}

/// One image in the strip: full-resolution source plus cached downscaled copies.
struct CombineItem: Identifiable {
    let id = UUID()
    let source: CombineImage
    let preview: CombineImage
    let thumbnail: CGImage
}

/// Settings of the Split mode.
struct SplitSettings: Equatable {
    var axis: SplitAxis = .horizontal
    var method: SplitMethod = .equal
    var count = 2
    var customCuts: [Double] = []

    /// Effective cut fractions (sorted, inside 0…1).
    var cuts: [Double] {
        method == .equal ? SplitRenderer.equalCuts(count: count) : SplitRenderer.normalizedCuts(customCuts)
    }
}

/// State of one Combine / Split window.
@MainActor
@Observable
final class CombineViewModel {
    static let previewMaxPixels: CGFloat = 1600
    static let thumbnailMaxPixels: CGFloat = 160
    private static let previewDebounce: Duration = .milliseconds(30)

    var mode: WorkspaceMode = .combine
    var layout: CombineLayout = .standard {
        didSet { if layout != oldValue { schedulePreview() } }
    }

    var split = SplitSettings() {
        didSet { clampSelectedSlice() }
    }

    var selectedItemID: UUID? {
        didSet { if selectedItemID != oldValue { selectedSliceIndex = 0 } }
    }

    var selectedSliceIndex = 0
    var isDropTargeted = false
    private(set) var items: [CombineItem] = []
    private(set) var preview: CGImage?
    /// Bumped on every new preview frame; drives the cross-fade.
    private(set) var previewGeneration = 0
    var isExporting = false

    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var onRequestClose: (() -> Void)?
    @ObservationIgnored let onExport: @MainActor (CGImage, ExportAction) -> Void
    @ObservationIgnored private var isRendering = false
    @ObservationIgnored private var needsRender = false

    init(captures: [CaptureResult], onExport: @escaping @MainActor (CGImage, ExportAction) -> Void) {
        self.onExport = onExport
        items = captures.map { Self.makeItem(CombineImage(image: $0.image, scale: $0.scale)) }
        selectedItemID = items.first?.id
        if captures.count == 1 { mode = .split }
        schedulePreview()
    }

    // MARK: Derived

    var sources: [CombineImage] { items.map(\.source) }

    /// Final combined size in pixels.
    var outputPixelSize: CGSize {
        guard !items.isEmpty else { return .zero }
        return fullPlan().canvasSize
    }

    /// Image that Split operates on: the selected strip item, else the first one.
    var splitSource: CombineItem? {
        items.first { $0.id == selectedItemID } ?? items.first
    }

    var sliceRects: [CGRect] {
        guard let source = splitSource?.source.image else { return [] }
        let size = CGSize(width: source.width, height: source.height)
        return SplitRenderer.sliceRects(pixelSize: size, axis: split.axis, cuts: split.cuts)
    }

    func fullPlan() -> CombinePlan {
        CombineRenderer.plan(
            sizes: sources.map(\.pointSize),
            layout: layout,
            outputScale: CombineRenderer.outputScale(for: sources)
        )
    }

    // MARK: Items

    func add(_ images: [CombineImage]) {
        guard !images.isEmpty else {
            NSSound.beep()
            return
        }
        let newItems = images.map(Self.makeItem)
        items += newItems
        if selectedItemID == nil { selectedItemID = newItems.first?.id }
        schedulePreview()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        if selectedItemID == id { selectedItemID = items.first?.id }
        schedulePreview()
    }

    /// Moves the dragged item to the position of `target`.
    func move(_ dragged: UUID, onto target: UUID) {
        guard dragged != target,
              let from = items.firstIndex(where: { $0.id == dragged }),
              let to = items.firstIndex(where: { $0.id == target })
        else { return }
        var reordered = items
        let item = reordered.remove(at: from)
        reordered.insert(item, at: to)
        items = reordered
        schedulePreview()
    }

    func addFromPanel() {
        ImageImporter.chooseImages(for: window) { [weak self] images in self?.add(images) }
    }

    func pasteImages() {
        add(ImageImporter.imagesFromPasteboard())
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        ImageImporter.load(providers: providers) { [weak self] image in self?.add([image]) }
    }

    private static func makeItem(_ source: CombineImage) -> CombineItem {
        CombineItem(
            source: source,
            preview: ImageLoading.downscaled(source, maxPixels: previewMaxPixels),
            thumbnail: ImageLoading.downscaled(source, maxPixels: thumbnailMaxPixels).image
        )
    }

    private func clampSelectedSlice() {
        let count = sliceRects.count
        if selectedSliceIndex >= count { selectedSliceIndex = max(0, count - 1) }
    }

    // MARK: Preview

    /// Coalesces changes: waits briefly, then at most one background render runs at a time
    /// and the latest state is rendered as soon as the previous frame lands.
    func schedulePreview() {
        needsRender = true
        guard !isRendering else { return }
        isRendering = true
        Task { [weak self] in
            try? await Task.sleep(for: Self.previewDebounce)
            await self?.drainPreviewRenders()
        }
    }

    private func drainPreviewRenders() async {
        while needsRender {
            needsRender = false
            let images = items.map(\.preview)
            let layout = layout
            let scale = previewScale()
            let box = await Task.detached(priority: .userInitiated) {
                CombineRenderer.render(images: images, layout: layout, outputScale: scale).map(ImageBox.init)
            }.value
            if box == nil, !images.isEmpty {
                Log.editor.error("Combine preview render failed")
            }
            preview = box?.image
            previewGeneration &+= 1
        }
        isRendering = false
    }

    /// Output scale that keeps the preview's longest side near `previewMaxPixels`.
    private func previewScale() -> CGFloat {
        guard !items.isEmpty else { return 1 }
        let plan = fullPlan()
        let longest = max(plan.canvasSize.width, plan.canvasSize.height)
        return plan.outputScale * min(1, Self.previewMaxPixels / max(longest, 1))
    }
}
