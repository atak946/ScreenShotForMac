import AppKit
import ShotCore

/// One run of the interactive ruler across all displays.
@MainActor
final class MeasureSession {
    struct Display {
        let geometry: DisplayGeometry
        let buffer: PixelBuffer
        let window: MeasureOverlayWindow
    }

    struct Cursor: Equatable {
        let display: Int
        let pixel: PixelPoint
    }

    struct Box {
        let display: Int
        let rect: PixelRect
        let isSnapped: Bool
    }

    struct DragStart {
        let display: Int
        let global: CGPoint
        var isDragging: Bool
    }

    static let dragThreshold: CGFloat = 3
    static let toleranceStep = 2
    static let shiftStep = 10
    private static let badgeDuration: Duration = .milliseconds(1200)

    private let snapshots: [CaptureResult]
    private let buffers: [PixelBuffer?]
    let copyText: @MainActor (String) -> Void

    var displays: [Display] = []
    var cursor: Cursor?
    var box: Box?
    var drag: DragStart?
    var unit: MeasureUnit = .points
    var tolerance = EdgeScanner.defaultTolerance
    private var badge: (display: Int, text: String)?
    private var badgeTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<Void, Never>?
    private var resignObserver: NSObjectProtocol?

    init(snapshots: [CaptureResult], buffers: [PixelBuffer?], copyText: @escaping @MainActor (String) -> Void) {
        self.snapshots = snapshots
        self.buffers = buffers
        self.copyText = copyText
    }

    func run() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    // MARK: Lifecycle

    private func start() {
        displays = NSScreen.screens.enumerated().compactMap { index, screen in
            makeDisplay(for: screen, index: index)
        }
        guard !displays.isEmpty else {
            Log.tools.error("Measure: no usable snapshot for any screen")
            finish()
            return
        }
        displays.forEach { $0.window.orderFrontRegardless() }
        NSApp.activate()
        let mouse = NSEvent.mouseLocation
        let keyIndex = displays.firstIndex { $0.geometry.contains(global: mouse) } ?? 0
        displays[keyIndex].window.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
        observeAppDeactivation()
        locate(mouse)
    }

    private func makeDisplay(for screen: NSScreen, index: Int) -> Display? {
        let snapshotIndex = snapshots.firstIndex { $0.screenRect.equalTo(screen.frame) }
            ?? (snapshots.indices.contains(index) ? index : nil)
        guard let snapshotIndex, let buffer = buffers[snapshotIndex] else { return nil }
        let capture = snapshots[snapshotIndex]
        guard let geometry = DisplayGeometry(
            screenRect: capture.screenRect, pixelWidth: buffer.width, pixelHeight: buffer.height
        ) else { return nil }
        let window = MeasureOverlayWindow(screen: screen, snapshot: capture.image)
        window.overlayDelegate = self
        return Display(geometry: geometry, buffer: buffer, window: window)
    }

    private func observeAppDeactivation() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
    }

    func finish() {
        guard let continuation else { return }
        self.continuation = nil
        badgeTask?.cancel()
        badgeTask = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        displays.forEach { display in
            display.window.overlayDelegate = nil
            display.window.orderOut(nil)
            display.window.close()
        }
        if !displays.isEmpty { NSCursor.pop() }
        displays = []
        continuation.resume()
    }

    // MARK: State helpers

    func displayIndex(at global: CGPoint) -> Int? {
        displays.firstIndex { $0.geometry.contains(global: global) }
    }

    func locate(_ global: CGPoint) {
        guard !displays.isEmpty else { return }
        let index = displayIndex(at: global) ?? cursor?.display ?? 0
        cursor = Cursor(display: index, pixel: displays[index].geometry.pixel(atGlobal: global))
        refresh()
    }

    func scanner(for display: Int) -> EdgeScanner {
        EdgeScanner(buffer: displays[display].buffer, tolerance: tolerance)
    }

    func formatter(for display: Int) -> MeasureFormatter {
        let geometry = displays[display].geometry
        return MeasureFormatter(
            scaleX: geometry.scaleX,
            scaleY: geometry.scaleY,
            primary: unit,
            showsSecondary: NSEvent.modifierFlags.contains(.shift)
        )
    }

    func showBadge(_ text: String, on display: Int) {
        badge = (display, text)
        badgeTask?.cancel()
        badgeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.badgeDuration)
            guard !Task.isCancelled, let self else { return }
            badge = nil
            refresh()
        }
        refresh()
    }

    // MARK: Rendering

    func refresh() {
        for (index, display) in displays.enumerated() {
            display.window.measureView.show(scene(for: index))
        }
    }

    private func scene(for index: Int) -> MeasureScene {
        let hover = cursor.flatMap { $0.display == index ? hoverGuide(for: $0) : nil }
        let boxGuide = box.flatMap { $0.display == index ? self.boxGuide(for: $0) : nil }
        let badgeGuide = badge.flatMap { badge -> Badge? in
            guard badge.display == index else { return nil }
            let anchor = cursor
                .flatMap { $0.display == index ? displays[index].geometry.localPoint(forPixelCenter: $0.pixel) : nil } ?? .zero
            return Badge(text: badge.text, anchor: anchor)
        }
        return MeasureScene(hover: hover, box: boxGuide, badge: badgeGuide)
    }

    private func hoverGuide(for cursor: Cursor) -> HoverGuide {
        let geometry = displays[cursor.display].geometry
        let span = scanner(for: cursor.display).span(around: cursor.pixel)
        let center = geometry.localPoint(forPixelCenter: cursor.pixel)
        let horizontal = Segment(
            start: CGPoint(x: geometry.localX(pixelEdge: span.minX), y: center.y),
            end: CGPoint(x: geometry.localX(pixelEdge: span.maxX + 1), y: center.y)
        )
        let vertical = Segment(
            start: CGPoint(x: center.x, y: geometry.localY(pixelEdge: span.maxY + 1)),
            end: CGPoint(x: center.x, y: geometry.localY(pixelEdge: span.minY))
        )
        let format = formatter(for: cursor.display)
        return HoverGuide(
            horizontal: horizontal,
            vertical: vertical,
            horizontalLabel: format.width(span.width),
            verticalLabel: format.height(span.height)
        )
    }

    private func boxGuide(for box: Box) -> BoxGuide {
        let geometry = displays[box.display].geometry
        let label = formatter(for: box.display).size(width: box.rect.width, height: box.rect.height)
        return BoxGuide(rect: geometry.localRect(for: box.rect), label: label, isSnapped: box.isSnapped)
    }
}
