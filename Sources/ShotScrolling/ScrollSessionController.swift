import AppKit
import ShotCore

/// Runs one scrolling session after the area has been selected: border, panel, frame loop,
/// optional auto-scroll and the final composition. Every window is removed on every exit path.
@MainActor
final class ScrollSessionController {
    private enum Outcome {
        case done
        case cancelled
        case failed(CaptureError)
    }

    private static let frameInterval: Duration = .milliseconds(110)
    private static let maxConsecutiveFailures = 5
    /// ~1 s of unchanged frames while auto-scrolling means the end was reached.
    private static let autoStopUnchangedFrames = 9
    private static let escapeKeyCode: UInt16 = 53
    private static let returnKeyCode: UInt16 = 36

    private let selection: ScrollSelection
    private let stitcher = ImageStitcher()
    private let autoScroller = AutoScroller()
    private var border: ScrollBorderWindow?
    private var panel: ScrollSessionPanel?
    private var loopTask: Task<Void, Never>?
    private var keyMonitors: [Any] = []
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var unchangedStreak = 0

    init(selection: ScrollSelection) {
        self.selection = selection
    }

    /// Returns the stitched image, or nil when cancelled.
    func run() async throws -> SendableImage? {
        guard let displayID = selection.displayID else { throw CaptureError.noDisplay }
        showChrome()
        defer { tearDown() }
        let request = GrabRequest(
            displayID: displayID,
            sourceRect: selection.displayLocalRect,
            scale: selection.screen.backingScaleFactor
        )
        let grabber = try await FrameGrabber.make(request)
        let outcome = await withCheckedContinuation { continuation in
            self.continuation = continuation
            loopTask = Task { [weak self] in await self?.captureLoop(grabber) }
        }
        autoScroller.stop()
        loopTask?.cancel()
        await loopTask?.value
        loopTask = nil
        switch outcome {
        case .cancelled:
            Log.capture.info("Scrolling capture cancelled")
            return nil
        case let .failed(error):
            throw error
        case .done:
            guard let image = await stitcher.compose() else {
                throw CaptureError.captureFailed(String(localized: "No frames were captured.", bundle: .module))
            }
            return image
        }
    }

    // MARK: - Frame loop

    private func captureLoop(_ grabber: FrameGrabber) async {
        var failures = 0
        while !Task.isCancelled {
            let start = ContinuousClock.now
            do {
                let frame = try await grabber.grab()
                guard !Task.isCancelled else { return }
                await handle(stitcher.add(frame))
                failures = 0
            } catch {
                failures += 1
                if failures >= Self.maxConsecutiveFailures {
                    finish(.failed(error as? CaptureError ?? .captureFailed(error.localizedDescription)))
                    return
                }
            }
            let remaining = Self.frameInterval - (ContinuousClock.now - start)
            if remaining > .zero { try? await Task.sleep(for: remaining) }
        }
    }

    private func handle(_ update: StitchUpdate) {
        panel?.updateSize(pixelWidth: update.pixelWidth, pixelHeight: update.pixelHeight, frameHeight: update.frameHeight)
        unchangedStreak = update.status == .unchanged ? unchangedStreak + 1 : 0
        switch update.status {
        case .started, .appended:
            panel?.setStatus(autoScroller.isRunning ? String(localized: "Auto-scrolling…", bundle: .module) : String(
                localized: "Scroll now…",
                bundle: .module
            ))
        case .unchanged:
            if autoScroller.isRunning, unchangedStreak >= Self.autoStopUnchangedFrames {
                stopAutoScroll()
                panel?.setStatus(String(localized: "Reached the end. Click Done.", bundle: .module))
            }
        case .scrolledUp:
            panel?.setStatus(String(localized: "Scrolling up is ignored; scroll down.", bundle: .module))
        case .noMatch:
            panel?.setStatus(String(localized: "Lost track; scroll back up a little.", bundle: .module))
        case .capReached:
            stopAutoScroll()
            panel?.setStatus(String(localized: "Maximum height reached. Click Done.", bundle: .module))
        }
    }

    // MARK: - Actions

    private func toggleAutoScroll() {
        if autoScroller.isRunning {
            stopAutoScroll()
            return
        }
        let center = CGPoint(x: selection.rect.midX, y: selection.rect.midY)
        autoScroller.start(at: center, areaHeight: selection.rect.height)
        unchangedStreak = 0
        panel?.setAutoScrolling(autoScroller.isRunning)
        if autoScroller.isRunning { panel?.setStatus(String(localized: "Auto-scrolling…", bundle: .module)) }
    }

    private func stopAutoScroll() {
        autoScroller.stop()
        panel?.setAutoScrolling(false)
    }

    private func finish(_ outcome: Outcome) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: outcome)
    }

    // MARK: - Chrome

    private func showChrome() {
        let border = ScrollBorderWindow(area: selection.rect)
        let actions = ScrollPanelActions(
            toggleAutoScroll: { [weak self] in self?.toggleAutoScroll() },
            done: { [weak self] in self?.finish(.done) },
            cancel: { [weak self] in self?.finish(.cancelled) }
        )
        let panel = ScrollSessionPanel(
            area: selection.rect,
            screen: selection.screen,
            actions: actions,
            canAutoScroll: AutoScroller.isPermitted
        )
        border.orderFrontRegardless()
        panel.orderFrontRegardless()
        self.border = border
        self.panel = panel
        installKeyMonitors()
    }

    /// Esc cancels, Return finishes. The global monitor only fires with Accessibility permission.
    private func installKeyMonitors() {
        let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, handleKey(event.keyCode) else { return event }
            return nil
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            MainActor.assumeIsolated { _ = self?.handleKey(keyCode) }
        }
        keyMonitors = [local, global].compactMap(\.self)
    }

    private func handleKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case Self.escapeKeyCode:
            finish(.cancelled)
            return true
        case Self.returnKeyCode:
            finish(.done)
            return true
        default:
            return false
        }
    }

    private func tearDown() {
        autoScroller.stop()
        loopTask?.cancel()
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors = []
        [border as NSWindow?, panel as NSWindow?].compactMap(\.self).forEach { window in
            window.orderOut(nil)
            window.close()
        }
        border = nil
        panel = nil
        finish(.cancelled)
    }
}
