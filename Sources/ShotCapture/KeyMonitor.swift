import AppKit

/// Key codes used by the capture overlays.
enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let space: UInt16 = 49
    static let tab: UInt16 = 48
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

/// Routes key events to a handler through a local monitor (events delivered to this app,
/// whichever window is key) and, best effort, a global monitor (events delivered to other
/// apps when the overlay could not become key; macOS may withhold these without
/// Input Monitoring / Accessibility permission).
@MainActor
final class KeyMonitor {
    /// Return true when the event was handled and must not be dispatched further.
    typealias Handler = @MainActor (NSEvent) -> Bool

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func start(_ handler: @escaping Handler) {
        stop()
        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            let handled = MainActor.assumeIsolated { handler(event) }
            return handled ? nil : event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated { _ = handler(event) }
        }
    }

    func stop() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }
}
