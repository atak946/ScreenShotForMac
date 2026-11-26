import AppKit
import ShotCore

/// One run of the interactive color picker across all displays.
@MainActor
final class ColorPickerSession: ColorPickerOverlayDelegate {
    private struct Display {
        let sampler: PixelSampler
        let window: ColorPickerOverlayWindow
    }

    private enum KeyCode {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let tab: UInt16 = 48
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    private static let shiftStep = 10

    private let snapshots: [CaptureResult]
    private var format: ColorFormat
    private var displays: [Display] = []
    private var current: (index: Int, pixel: PixelCoordinate)?
    private var continuation: CheckedContinuation<PickedColor?, Never>?
    private var resignObserver: NSObjectProtocol?

    init(snapshots: [CaptureResult], format: ColorFormat) {
        self.snapshots = snapshots
        self.format = format
    }

    func run() async -> PickedColor? {
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
            Log.tools.error("Color picker: no usable snapshot for any screen")
            finish(nil)
            return
        }
        displays.forEach { $0.window.orderFrontRegardless() }
        NSApp.activate()
        let keyIndex = displays.firstIndex { $0.sampler.screenRect.contains(NSEvent.mouseLocation) } ?? 0
        displays[keyIndex].window.makeKeyAndOrderFront(nil)
        NSCursor.hide()
        observeAppDeactivation()
        locate(NSEvent.mouseLocation)
    }

    private func makeDisplay(for screen: NSScreen, index: Int) -> Display? {
        let match = snapshots.first { $0.screenRect.equalTo(screen.frame) }
            ?? (snapshots.indices.contains(index) ? snapshots[index] : nil)
        guard let capture = match, let sampler = PixelSampler(capture: capture) else { return nil }
        let window = ColorPickerOverlayWindow(screen: screen, snapshot: capture.image)
        window.overlayDelegate = self
        return Display(sampler: sampler, window: window)
    }

    private func observeAppDeactivation() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(nil) }
        }
    }

    private func finish(_ color: PickedColor?) {
        guard let continuation else { return }
        self.continuation = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        displays.forEach { display in
            display.window.overlayDelegate = nil
            display.window.orderOut(nil)
            display.window.close()
        }
        if !displays.isEmpty { NSCursor.unhide() }
        displays = []
        continuation.resume(returning: color)
    }

    // MARK: ColorPickerOverlayDelegate

    func overlayMouseMoved() { locate(NSEvent.mouseLocation) }

    func overlayClicked() { pickCurrent() }

    func overlayCancelled() { finish(nil) }

    func overlayKeyDown(_ event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? Self.shiftStep : 1
        switch event.keyCode {
        case KeyCode.escape: finish(nil)
        case KeyCode.returnKey, KeyCode.keypadEnter: pickCurrent()
        case KeyCode.tab: cycleFormat(backwards: event.modifierFlags.contains(.shift))
        case KeyCode.left: move(dx: -step, dy: 0)
        case KeyCode.right: move(dx: step, dy: 0)
        case KeyCode.up: move(dx: 0, dy: -step)
        case KeyCode.down: move(dx: 0, dy: step)
        default: break
        }
    }

    // MARK: Interaction

    private func pickCurrent() {
        guard let current, displays.indices.contains(current.index) else {
            finish(nil)
            return
        }
        let color = displays[current.index].sampler.color(at: current.pixel)
        if color == nil { Log.tools.error("Color picker: failed to read pixel color") }
        finish(color)
    }

    private func cycleFormat(backwards: Bool) {
        let all = ColorFormat.allCases
        guard let position = all.firstIndex(of: format) else { return }
        let offset = backwards ? all.count - 1 : 1
        format = all[(position + offset) % all.count]
        refresh()
    }

    private func move(dx: Int, dy: Int) {
        guard let current, displays.indices.contains(current.index) else { return }
        let sampler = displays[current.index].sampler
        let pixel = sampler.clamped(x: current.pixel.x + dx, y: current.pixel.y + dy)
        warpCursor(to: sampler.globalPoint(forPixelCenter: pixel))
        self.current = (current.index, pixel)
        refresh()
    }

    private func locate(_ point: CGPoint) {
        guard !displays.isEmpty else { return }
        let index = displays.firstIndex { $0.sampler.screenRect.contains(point) } ?? current?.index ?? 0
        current = (index, displays[index].sampler.pixel(at: point))
        refresh()
    }

    private func refresh() {
        for (index, display) in displays.enumerated() {
            guard let current, current.index == index else {
                display.window.overlayView.hideLoupe()
                continue
            }
            showLoupe(on: display, pixel: current.pixel)
        }
    }

    private func showLoupe(on display: Display, pixel: PixelCoordinate) {
        let sampler = display.sampler
        guard let color = sampler.color(at: pixel) else { return }
        let content = LoupeContent(
            region: sampler.region(around: pixel, radius: LoupeView.gridPixels / 2),
            color: color,
            label: ColorFormatter.string(for: color, format: format)
        )
        let global = sampler.globalPoint(forPixelCenter: pixel)
        let origin = display.window.frame.origin
        display.window.overlayView.showLoupe(content, centeredAt: CGPoint(x: global.x - origin.x, y: global.y - origin.y))
    }

    /// Moves the system cursor; CG uses a top-left origin relative to the primary display.
    private func warpCursor(to point: CGPoint) {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: primaryHeight - point.y))
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
