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
    /// `keepOnTop` keeps it above other apps' windows (floating level) until it closes.
    public static func present(_ window: NSWindow, keepOnTop: Bool = false) {
        track(window)
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            applyDockIcon()
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        // Cooperative `NSApp.activate()` (macOS 14+) is silently refused when the frontmost
        // app hasn't yielded (menu-bar click, or the capture overlay just handed focus back),
        // so the window opened behind other apps. Force activation, and float the window
        // briefly so it lands on top even if activation still loses the race.
        let originalLevel = window.level
        if originalLevel == .normal { window.level = .floating }
        forceActivate(window)
        for delay in reassertDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard window.isVisible else { return }
                forceActivate(window)
            }
        }
        guard !keepOnTop else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + floatDuration) {
            if originalLevel == .normal, window.level == .floating { window.level = .normal }
        }
    }

    private static func forceActivate(_ window: NSWindow) {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static let floatDuration: TimeInterval = 0.8
    private static let reassertDelays: [TimeInterval] = [0, 0.15, 0.4]

    /// An LSUIElement app switched to `.regular` at runtime can get a generic Dock tile;
    /// set the bundle icon explicitly so the Dock shows the real app icon.
    private static func applyDockIcon() {
        NSApp.applicationIconImage = AppIcon.image
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

/// The real app icon, read from the bundle (Assets.car / AppIcon.icns).
/// `NSImage(named: NSImage.applicationIconName)` and LaunchServices can return a stale generic icon.
@MainActor
public enum AppIcon {
    public static var image: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        return NSImage(named: "AppIcon") ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}
