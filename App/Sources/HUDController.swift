import AppKit
import ShotCore

/// Transient, non-activating glass toast shown bottom-center above the Dock of the active screen.
@MainActor
final class HUDController: UserNotifying {
    private static let visibleDuration: TimeInterval = 1.8
    /// Progress toasts stay until replaced; this only bounds a stuck one.
    private static let progressDuration: TimeInterval = 30
    private static let errorDuration: TimeInterval = 3.5
    private static let slideDistance: CGFloat = 14
    private static let bottomInset: CGFloat = 72
    private static let height: CGFloat = 40
    private static let maxTextWidth: CGFloat = 520

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func showHUD(_ message: String) {
        present(message, symbol: "checkmark.circle.fill", tint: DS.Palette.success)
    }

    func showError(_ error: Error) {
        Log.app.error("User-facing error: \(error.localizedDescription, privacy: .public)")
        present(
            error.localizedDescription, symbol: "exclamationmark.triangle.fill", tint: DS.Palette.warning,
            duration: Self.errorDuration
        )
    }

    /// Ongoing work (uploads, workflow steps); stays visible until the next toast.
    func showProgress(_ message: String) {
        present(message, symbol: "hourglass", tint: .controlAccentColor, duration: Self.progressDuration)
    }

    private func present(_ message: String, symbol: String, tint: NSColor, duration: TimeInterval = HUDController.visibleDuration) {
        hideTask?.cancel()
        panel?.orderOut(nil)

        let content = makeContent(message: message, symbol: symbol, tint: tint)
        let size = content.fittingSize
        let finalFrame = Self.frame(for: size)
        let panel = FloatingPanel.make(size: size, level: .statusBar)
        panel.ignoresMouseEvents = true
        panel.collectionBehavior.insert(.transient)
        panel.contentView = content
        panel.setFrame(finalFrame.offsetBy(dx: 0, dy: -Self.slideDistance), display: false)
        panel.alphaValue = 0
        self.panel = panel
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.normal
            context.timingFunction = DS.Motion.easeOut
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.dismiss(panel)
        }
    }

    private func dismiss(_ panel: NSPanel) {
        let target = panel.frame.offsetBy(dx: 0, dy: -Self.slideDistance / 2)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DS.Motion.normal
            panel.animator().alphaValue = 0
            panel.animator().setFrame(target, display: true)
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private static func frame(for size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        return CGRect(
            x: (visible.midX - size.width / 2).rounded(),
            y: visible.minY + bottomInset,
            width: size.width,
            height: size.height
        )
    }

    private func makeContent(message: String, symbol: String, tint: NSColor) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = tint
        icon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)

        let label = NSTextField(labelWithString: message)
        label.font = DS.Font.hudTitle
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        let stack = NSStackView(views: [icon, label])
        stack.spacing = DS.Space.s
        stack.edgeInsets = NSEdgeInsets(top: 0, left: DS.Space.m + DS.Space.xxs, bottom: 0, right: DS.Space.l)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let surface = GlassSurfaceView(cornerRadius: Self.height / 2)
        surface.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            surface.heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxTextWidth),
        ])
        return surface
    }
}
