import AppKit
import ShotCore

/// Controller for one floating thumbnail: panel, timer, gestures and actions.
@MainActor
final class QuickAccessItem: QuickAccessThumbnailDelegate {
    private static let swipeDismissDistance: CGFloat = 60
    private static let animationDuration: TimeInterval = 0.25

    /// Size of the visible card (layout unit of the presenter).
    let size: NSSize
    /// Panel size: the card plus the transparent shadow margin.
    private var panelSize: NSSize {
        NSSize(width: size.width + Self.inset * 2, height: size.height + Self.inset * 2)
    }

    private static var inset: CGFloat { QuickAccessThumbnailView.inset }
    var restingOrigin: NSPoint = .zero
    private(set) var isDismissing = false

    private let capture: CaptureResult
    private let handlers: QuickAccessHandlers
    private let panel: QuickAccessPanel
    private let thumbnail: QuickAccessThumbnailView
    private let dragExporter: DragExporter
    private let dragBaseName: String
    private let autoCloseSeconds: Double
    private let onDismissed: (QuickAccessItem) -> Void
    private var dragFileURL: URL?
    private var isHovering = false
    private var timerTask: Task<Void, Never>?

    init(
        capture: CaptureResult,
        handlers: QuickAccessHandlers,
        size: NSSize,
        configuration: QuickAccessConfiguration,
        onDismissed: @escaping (QuickAccessItem) -> Void
    ) {
        self.capture = capture
        self.handlers = handlers
        self.size = size
        dragExporter = configuration.dragExporter
        dragBaseName = configuration.dragBaseName
        autoCloseSeconds = configuration.autoCloseSeconds
        self.onDismissed = onDismissed
        let preview = Self.previewImage(for: capture.image, size: size)
        thumbnail = QuickAccessThumbnailView(
            image: preview, showsPin: handlers.onPin != nil, showsUpload: handlers.onUpload != nil
        )
        panel = QuickAccessPanel(contentSize: NSSize(width: size.width + Self.inset * 2, height: size.height + Self.inset * 2))
        panel.contentView = thumbnail
        thumbnail.delegate = self
    }

    // MARK: Presentation

    func present(at origin: NSPoint, offscreenX: CGFloat) {
        restingOrigin = origin
        panel.setFrame(panelFrame(at: NSPoint(x: offscreenX, y: origin.y)), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        animate(to: origin, alpha: 1)
        scheduleAutoClose()
    }

    func move(to origin: NSPoint) {
        restingOrigin = origin
        guard !isDismissing else { return }
        animate(to: origin, alpha: 1)
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        timerTask?.cancel()
        let target = NSPoint(x: restingOrigin.x - size.width - 40, y: panel.frame.origin.y + Self.inset)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(panelFrame(at: target), display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.finishDismiss() }
        }
    }

    private func finishDismiss() {
        panel.orderOut(nil)
        panel.contentView = nil
        onDismissed(self)
    }

    private func animate(to origin: NSPoint, alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            context.timingFunction = DS.Motion.easeOut
            panel.animator().setFrame(panelFrame(at: origin), display: true)
            panel.animator().alphaValue = alpha
        }
    }

    /// Panel frame whose card sits at `cardOrigin`.
    private func panelFrame(at cardOrigin: NSPoint) -> NSRect {
        NSRect(origin: NSPoint(x: cardOrigin.x - Self.inset, y: cardOrigin.y - Self.inset), size: panelSize)
    }

    // MARK: Auto close

    private func scheduleAutoClose() {
        timerTask?.cancel()
        guard autoCloseSeconds > 0, !isHovering, !isDismissing else { return }
        let seconds = autoCloseSeconds
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    // MARK: QuickAccessThumbnailDelegate

    func thumbnail(didRequest action: QuickAccessAction) {
        switch action {
        case .edit: handlers.onEdit()
        case .copy: handlers.onCopy()
        case .save: handlers.onSave()
        case .pin: handlers.onPin?()
        case .upload: handlers.onUpload?()
        case .close: break
        }
        dismiss()
    }

    func thumbnail(hoverChanged isHovering: Bool) {
        self.isHovering = isHovering
        if isHovering {
            timerTask?.cancel()
        } else {
            scheduleAutoClose()
        }
    }

    func thumbnailFileURLForDrag() -> URL? {
        if let dragFileURL, FileManager.default.fileExists(atPath: dragFileURL.path) {
            return dragFileURL
        }
        do {
            let url = try dragExporter.writeTemporaryPNG(capture.image, scale: capture.scale, baseName: dragBaseName)
            dragFileURL = url
            return url
        } catch {
            Log.export.error("Drag export failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func thumbnail(didEndFileDrag succeeded: Bool) {
        if succeeded {
            dismiss()
        } else {
            scheduleAutoClose()
        }
    }

    func thumbnail(swipedBy offset: CGFloat) {
        guard !isDismissing else { return }
        timerTask?.cancel()
        panel.setFrame(panelFrame(at: NSPoint(x: restingOrigin.x + offset, y: restingOrigin.y)), display: true)
        panel.alphaValue = max(0.2, 1 + offset / size.width)
    }

    func thumbnail(didEndSwipe offset: CGFloat) {
        if offset <= -Self.swipeDismissDistance {
            dismiss()
        } else {
            animate(to: restingOrigin, alpha: 1)
            scheduleAutoClose()
        }
    }

    // MARK: Helpers

    private static func previewImage(for image: CGImage, size: NSSize) -> CGImage {
        let targetWidth = Int(size.width * 2)
        guard image.width > targetWidth * 2 else { return image }
        let ratio = CGFloat(image.height) / CGFloat(max(image.width, 1))
        let targetHeight = max(1, Int(CGFloat(targetWidth) * ratio))
        return ImageScaler.resize(image, width: targetWidth, height: targetHeight) ?? image
    }
}

/// Values shared by all items of a presenter.
struct QuickAccessConfiguration {
    let dragExporter: DragExporter
    let dragBaseName: String
    let autoCloseSeconds: Double
}
