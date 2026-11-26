import AppKit
import ShotCore

/// "Capture last area" and delayed (timer) captures.
extension CaptureService {
    private static let maxDelaySeconds = 60

    /// Re-captures the last selected area without UI. Falls back to the interactive
    /// area flow when nothing was stored or the display is gone.
    public func captureLastArea() async throws -> CaptureResult? {
        try await runSession("last area") {
            let sourceApp = self.frontmostAppName()
            guard let stored = self.lastAreaStore.load(), let target = self.resolve(stored) else {
                Log.capture.info("No usable last area; falling back to interactive selection")
                return try await self.interactiveArea(sourceApp: sourceApp)
            }
            guard let snapshot = try await self.takeSnapshots(of: [target.screen]).first else {
                throw CaptureError.noDisplay
            }
            return try self.areaResult(rect: target.rect, snapshot: snapshot, sourceApp: sourceApp)
        }
    }

    /// Delayed capture.
    /// - `.area`: the user selects on the live screen, then a countdown runs inside the
    ///   selection and the area is captured without UI.
    /// - `.window`: countdown, then the front-most window under the cursor is captured
    ///   (falls back to the display under the cursor when there is none).
    /// - `.fullscreen`: countdown, then the display under the cursor is captured.
    public func captureDelayed(_ mode: CaptureMode, seconds: Int) async throws -> CaptureResult? {
        let delay = min(max(seconds, 0), Self.maxDelaySeconds)
        return try await runSession("delayed \(mode.rawValue)") {
            let sourceApp = self.frontmostAppName()
            switch mode {
            case .area:
                return try await self.delayedArea(seconds: delay, sourceApp: sourceApp)
            case .window:
                return try await self.delayedWindow(seconds: delay, sourceApp: sourceApp)
            case .fullscreen:
                let screen = self.screenUnderCursor()
                guard await self.countdown(seconds: delay, area: nil, on: screen) else { return nil }
                return try await self.fullscreen(of: screen, sourceApp: sourceApp)
            }
        }
    }

    // MARK: - Private

    private func delayedArea(seconds: Int, sourceApp: String?) async throws -> CaptureResult? {
        let windows = await LocatedWindow.locate((try? snapshotter.listWindows()) ?? [])
        let controller = AreaSelectionController(
            surfaces: NSScreen.screens.map(SelectionSurface.init(liveScreen:)),
            windows: windows,
            showMagnifier: false
        )
        guard let selection = await controller.run() else {
            Log.capture.info("Delayed area capture cancelled during selection")
            return nil
        }
        guard await countdown(seconds: seconds, area: selection.rect, on: selection.surface.screen) else {
            return nil
        }
        guard let snapshot = try await takeSnapshots(of: [selection.surface.screen]).first else {
            throw CaptureError.noDisplay
        }
        return try areaResult(
            rect: selection.rect,
            snapshot: snapshot,
            sourceApp: selection.window?.appName ?? sourceApp
        )
    }

    private func delayedWindow(seconds: Int, sourceApp: String?) async throws -> CaptureResult? {
        guard await countdown(seconds: seconds, area: nil, on: screenUnderCursor()) else { return nil }
        let mouse = NSEvent.mouseLocation
        let windows = try await LocatedWindow.locate(snapshotter.listWindows())
        if let window = windows.first(where: { $0.frame.contains(mouse) }) {
            return try await windowResult(for: window)
        }
        Log.capture.info("No window under the cursor after countdown; capturing the display instead")
        return try await fullscreen(of: screenUnderCursor(), sourceApp: sourceApp)
    }

    /// Returns false when the user cancelled the countdown.
    private func countdown(seconds: Int, area: CGRect?, on screen: NSScreen?) async -> Bool {
        guard let screen else { return true }
        // Keep the HUD in a local so it outlives the countdown (its key monitor holds it weakly).
        let hud = CountdownHUD()
        let completed = await hud.run(seconds: seconds, area: area, on: screen)
        if !completed { Log.capture.info("Delayed capture cancelled during countdown") }
        return completed
    }

    /// Maps a stored area onto the current display layout.
    private func resolve(_ stored: LastArea) -> (screen: NSScreen, rect: CGRect)? {
        let screens = NSScreen.screens
        let screen = screens.first { $0.displayID == stored.displayID }
            ?? screens.max { overlap($0.frame, stored.rect) < overlap($1.frame, stored.rect) }
        guard let screen, let rect = SelectionGeometry.clip(stored.rect, to: screen.frame),
              rect.width >= 1, rect.height >= 1 else { return nil }
        return (screen, rect)
    }

    private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
