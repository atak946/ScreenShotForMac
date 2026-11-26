import AppKit

/// Vertically centers the traffic lights in the custom 52pt titlebar
/// (the window has a transparent titlebar and no `NSToolbar`, so content stays clickable).
@MainActor
enum TrafficLights {
    private static let leadingMargin: CGFloat = 20

    static func center(in window: NSWindow, barHeight: CGFloat) {
        guard !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let miniaturize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let container = close.superview?.superview
        else { return }

        var containerFrame = container.frame
        containerFrame.size.height = barHeight
        containerFrame.origin.y = window.frame.height - barHeight
        container.frame = containerFrame

        let spacing = miniaturize.frame.minX - close.frame.minX
        for (index, button) in [close, miniaturize, zoom].enumerated() {
            let origin = CGPoint(
                x: leadingMargin + CGFloat(index) * spacing,
                y: ((barHeight - button.frame.height) / 2).rounded()
            )
            button.setFrameOrigin(origin)
        }
    }
}
