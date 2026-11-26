import AppKit
import ApplicationServices
import ShotCore

/// Posts synthetic scroll-wheel events at a fixed screen location. Requires Accessibility permission.
@MainActor
final class AutoScroller {
    private static let interval: Duration = .milliseconds(140)
    private static let minimumStep: Int32 = 20

    private var task: Task<Void, Never>?

    var isRunning: Bool { task != nil }

    static var isPermitted: Bool { AXIsProcessTrusted() }

    /// Starts scrolling down at `appKitPoint` (global AppKit coordinates) by a fraction of `areaHeight` per step.
    func start(at appKitPoint: CGPoint, areaHeight: CGFloat) {
        guard task == nil else { return }
        guard Self.isPermitted else {
            Log.capture.info("Auto-scroll unavailable: Accessibility permission missing")
            return
        }
        let location = Self.quartzPoint(from: appKitPoint)
        let step = max(Self.minimumStep, Int32((areaHeight * 0.25).rounded()))
        // Scroll events go to the window under the cursor, so park the cursor in the area.
        CGWarpMouseCursorPosition(location)
        task = Task { @MainActor in
            while !Task.isCancelled {
                Self.postScroll(at: location, step: step)
                try? await Task.sleep(for: Self.interval)
            }
        }
        Log.capture.info("Auto-scroll started")
    }

    func stop() {
        guard let task else { return }
        task.cancel()
        self.task = nil
        Log.capture.info("Auto-scroll stopped")
    }

    private static func postScroll(at location: CGPoint, step: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -step,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.location = location
        event.post(tap: .cghidEventTap)
    }

    /// AppKit global (bottom-left origin) to Quartz global (top-left origin).
    private static func quartzPoint(from point: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
