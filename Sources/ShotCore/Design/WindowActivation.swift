import AppKit

/// Brings regular windows (Settings, Editor, History, Backdrop, Onboarding) to the front
/// of a menu-bar (LSUIElement / `.accessory`) app.
///
/// Accessory apps can't reliably activate, so their windows open *behind* other apps.
/// While at least one tracked window is open, the app is switched to `.regular`
/// (Dock icon + ⌘-Tab, like CleanShot). When the last one closes it returns to `.accessory`.
@MainActor
public enum WindowActivation {
    private static var tracked: Set<ObjectIdentifier> = []
    private static var observers: [ObjectIdentifier: NSObjectProtocol] = [:]

    /// Shows `window` in front of every other app and tracks it until it closes.
    public static func present(_ window: NSWindow) {
        track(window)
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            applyDockIcon()
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Activation of a freshly-regular app can land one runloop later.
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// An LSUIElement app switched to `.regular` at runtime can get a generic Dock tile;
    /// set the bundle icon explicitly so the Dock shows the real app icon.
    private static func applyDockIcon() {
        let icon = NSImage(named: NSImage.applicationIconName)
            ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        NSApp.applicationIconImage = icon
        NSApp.dockTile.display()
    }

    private static func track(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard !tracked.contains(id) else { return }
        tracked.insert(id)
        observers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { untrack(id) }
        }
    }

    private static func untrack(_ id: ObjectIdentifier) {
        tracked.remove(id)
        if let observer = observers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        guard tracked.isEmpty else { return }
        // Defer so the closing window finishes its animation first.
        DispatchQueue.main.async {
            guard tracked.isEmpty else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
