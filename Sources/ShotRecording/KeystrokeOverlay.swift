import AppKit
import ShotCore

/// Click-through glass pill near the bottom of the recorded area showing the latest
/// key combo (e.g. `⌘⇧4`); fades out 1.2 s after the last key. Included in the capture.
/// Requires Accessibility access for the global key monitor.
@MainActor
final class KeystrokeOverlay {
    private static let visibleDuration: Duration = .milliseconds(1200)
    private static let bottomInset: CGFloat = DS.Space.xxl
    private static let bandHeight: CGFloat = 64
    private static let font = NSFont.systemFont(ofSize: 22, weight: .semibold)

    private let window: NSWindow
    private let pill = OverlayPill(font: font, verticalPadding: DS.Space.s)
    private let shortcutsOnly: Bool
    private var monitors: [Any] = []
    private var fadeTask: Task<Void, Never>?

    init(rect: CGRect, shortcutsOnly: Bool) {
        self.shortcutsOnly = shortcutsOnly
        let height = min(Self.bandHeight, rect.height)
        let frame = CGRect(
            x: rect.minX,
            y: rect.minY + min(Self.bottomInset, rect.height - height),
            width: rect.width,
            height: height
        )
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let content = NSView(frame: CGRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.addSubview(pill)
        window.contentView = content
    }

    /// Window server ID, used to keep this window in the capture.
    var windowID: CGWindowID {
        CGWindowID(window.windowNumber)
    }

    func show() {
        window.orderFrontRegardless()
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let snapshot = KeySnapshot(event)
            MainActor.assumeIsolated { self?.handle(snapshot) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let snapshot = KeySnapshot(event)
            MainActor.assumeIsolated { self?.handle(snapshot) }
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        fadeTask?.cancel()
        fadeTask = nil
        window.orderOut(nil)
    }

    // MARK: - Events

    private func handle(_ key: KeySnapshot) {
        if key.isFlagsChanged {
            let symbols = KeystrokeFormatter.modifierSymbols(key.flags)
            guard !symbols.isEmpty else { return }
            display(symbols)
            return
        }
        guard let label = KeystrokeFormatter.label(
            keyCode: key.keyCode, characters: key.characters, flags: key.flags, shortcutsOnly: shortcutsOnly
        ) else { return }
        display(label)
    }

    private func display(_ text: String) {
        let bounds = window.contentView?.bounds ?? .zero
        pill.show(text, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY), clampedTo: bounds)
        pill.alphaValue = 1
        scheduleFade()
    }

    private func scheduleFade() {
        fadeTask?.cancel()
        fadeTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.visibleDuration)
            } catch {
                return
            }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.normal
            pill.animator().alphaValue = 0
        }
    }
}

/// Sendable copy of the parts of an `NSEvent` the overlay needs.
private struct KeySnapshot: Sendable {
    let isFlagsChanged: Bool
    let keyCode: UInt16
    let characters: String?
    let flags: NSEvent.ModifierFlags

    init(_ event: NSEvent) {
        isFlagsChanged = event.type == .flagsChanged
        keyCode = event.keyCode
        characters = isFlagsChanged ? nil : event.charactersIgnoringModifiers
        flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }
}
