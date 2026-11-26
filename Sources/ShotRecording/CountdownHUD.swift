import AppKit
import ShotCore

/// A 3-2-1 countdown shown in the middle of the area about to be recorded.
@MainActor
final class CountdownHUD {
    private var panel: NSPanel?
    private var isCancelled = false

    /// Counts down `seconds`. Returns false when cancelled.
    func run(seconds: Int, centeredOn rect: CGRect) async -> Bool {
        let badge = CountdownBadgeView(ringColor: DS.Palette.recording)
        let panel = makePanel(centeredOn: rect, badge: badge)
        self.panel = panel
        panel.orderFrontRegardless()
        defer { close() }

        for remaining in stride(from: seconds, to: 0, by: -1) {
            guard !isCancelled else { return false }
            badge.show(remaining)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                Log.recording.info("Countdown task cancelled")
                return false
            }
        }
        return !isCancelled
    }

    func cancel() {
        isCancelled = true
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel(centeredOn rect: CGRect, badge: CountdownBadgeView) -> NSPanel {
        let side = CountdownBadgeView.side
        let panel = FloatingPanel.make(size: CGSize(width: side, height: side), level: .screenSaver)
        panel.setFrameOrigin(CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2))
        panel.ignoresMouseEvents = true
        panel.collectionBehavior.insert(.stationary)
        panel.contentView = badge
        return panel
    }
}
