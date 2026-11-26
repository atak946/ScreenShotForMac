import AppKit
import ShotCore
import SwiftUI

/// Hosts `OnboardingView` in a fixed-size, centered window with a transparent title bar.
@MainActor
public final class OnboardingWindowController {
    private var window: NSWindow?
    private let onFinish: @MainActor () -> Void
    private let requestScreenPermission: @MainActor () -> Void
    private let hasScreenPermission: @MainActor () -> Bool

    public init(
        onFinish: @escaping @MainActor () -> Void,
        requestScreenPermission: @escaping @MainActor () -> Void,
        hasScreenPermission: @escaping @MainActor () -> Bool
    ) {
        self.onFinish = onFinish
        self.requestScreenPermission = requestScreenPermission
        self.hasScreenPermission = hasScreenPermission
    }

    public func show() {
        let window = window ?? makeWindow()
        self.window = window
        WindowActivation.present(window)
    }

    public func close() {
        window?.close()
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(
            onFinish: { [weak self] in
                self?.close()
                self?.onFinish()
            },
            requestScreenPermission: requestScreenPermission,
            hasScreenPermission: hasScreenPermission
        )
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: OnboardingView.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.setContentSize(OnboardingView.size)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = String(localized: "Welcome", bundle: .module)
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenNone)
        window.center()
        return window
    }
}
