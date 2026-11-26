import AppKit
import ShotCore

/// Callbacks from a pin panel to its owner.
@MainActor
protocol PinPanelOwner: AnyObject {
    func pinDidClose(_ panel: PinPanel)
    func pinRequestsCloseAll()
    func pinClickThroughDidChange()
}

/// Shows captures as always-on-top floating panels ("pins").
@MainActor
public final class PinPresenter: PinPresenting, PinPanelOwner {
    private static let fitFraction: CGFloat = 0.9

    private var panels: [PinPanel] = []
    private var badge: ClickThroughBadge?

    public init() {}

    public var pinCount: Int { panels.count }

    public func pin(_ capture: CaptureResult, at screenRect: CGRect?) {
        let panel = PinPanel(image: capture.image, scale: capture.scale, owner: self)
        if let screenRect {
            panel.place(origin: screenRect.origin, zoom: 1)
        } else {
            placeCentered(panel, pointSize: capture.pointSize)
        }
        panels.append(panel)
        panel.present()
        Log.editor.info("Pinned \(capture.image.width)x\(capture.image.height) image (\(self.panels.count) pins)")
    }

    public func closeAllPins() {
        let current = panels
        panels = []
        current.forEach { $0.dismiss(notifyOwner: false) }
        updateBadge()
    }

    /// Restores mouse interaction on every pin that is in click-through mode.
    public func disableClickThroughForAll() {
        panels.filter(\.isClickThrough).forEach { $0.setClickThrough(false) }
        updateBadge()
    }

    // MARK: PinPanelOwner

    func pinDidClose(_ panel: PinPanel) {
        panels.removeAll { $0 === panel }
        updateBadge()
    }

    func pinRequestsCloseAll() {
        closeAllPins()
    }

    func pinClickThroughDidChange() {
        updateBadge()
    }

    // MARK: Private

    private func placeCentered(_ panel: PinPanel, pointSize: CGSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let fit = min(
            1,
            visible.width * Self.fitFraction / max(pointSize.width, 1),
            visible.height * Self.fitFraction / max(pointSize.height, 1)
        )
        let size = CGSize(width: pointSize.width * fit, height: pointSize.height * fit)
        let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        panel.place(origin: origin, zoom: fit)
    }

    private func updateBadge() {
        let count = panels.filter(\.isClickThrough).count
        guard count > 0 else {
            badge?.orderOut(nil)
            badge = nil
            return
        }
        let current = badge ?? ClickThroughBadge { [weak self] in self?.disableClickThroughForAll() }
        badge = current
        current.update(count: count)
    }
}
