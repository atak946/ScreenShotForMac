import AppKit
@preconcurrency import AVFoundation
import ShotCore

/// Floating, draggable, mirrored camera bubble shown over the recorded area.
/// Like the click highlighter it is deliberately included in the capture.
/// Right-click for size (S / M / L) and shape; the choice is remembered.
@MainActor
final class WebcamOverlay {
    private static let edgeInset: CGFloat = DS.Space.xl
    private static let roundedAspect: CGFloat = 4.0 / 3.0

    private let camera: CameraSession
    private let panel: NSPanel
    private let bubble: WebcamBubbleView
    private var shape: WebcamShape
    private var size: WebcamSize
    private var isClosed = false

    /// Returns nil when no camera could be opened.
    init?(prefs: RecordingExtrasPreferences) {
        guard let camera = CameraSession() else { return nil }
        self.camera = camera
        shape = prefs.webcamShape
        size = prefs.webcamSize
        bubble = WebcamBubbleView(session: camera.session)
        panel = FloatingPanel.make(
            size: Self.frameSize(shape: shape, size: size),
            level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        )
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior.insert(.stationary)
        panel.contentView = bubble
        bubble.menuProvider = { [weak self] in self?.makeMenu() }
        bubble.apply(shape: shape)
    }

    /// Window server ID, used to keep this window in the capture.
    var windowID: CGWindowID {
        CGWindowID(panel.windowNumber)
    }

    /// Places the bubble in the bottom-left corner of `rect` and starts the camera.
    func show(in rect: CGRect) {
        let frameSize = panel.frame.size
        let inset = min(Self.edgeInset, max(0, (rect.width - frameSize.width) / 2))
        panel.setFrameOrigin(CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        panel.orderFrontRegardless()
        camera.start()
    }

    /// Idempotent; safe to call from every teardown path.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        camera.stop()
        panel.orderOut(nil)
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for option in WebcamSize.allCases {
            let item = menu.addItem(withTitle: option.title, action: nil, keyEquivalent: "")
            item.state = option == size ? .on : .off
            item.representedObject = ClosureActionTarget { [weak self] in self?.resize(to: option) }
        }
        menu.addItem(.separator())
        for option in WebcamShape.allCases {
            let item = menu.addItem(withTitle: option.title, action: nil, keyEquivalent: "")
            item.state = option == shape ? .on : .off
            item.representedObject = ClosureActionTarget { [weak self] in self?.reshape(to: option) }
        }
        for item in menu.items where item.representedObject is ClosureActionTarget {
            item.target = item.representedObject as? ClosureActionTarget
            item.action = #selector(ClosureActionTarget.perform(_:))
        }
        return menu
    }

    private func resize(to newSize: WebcamSize) {
        size = newSize
        applyFrame()
        persist()
    }

    private func reshape(to newShape: WebcamShape) {
        shape = newShape
        bubble.apply(shape: newShape)
        applyFrame()
        persist()
    }

    /// Resizes around the current center, kept on the current screen.
    private func applyFrame() {
        let newSize = Self.frameSize(shape: shape, size: size)
        let old = panel.frame
        var frame = CGRect(
            x: old.midX - newSize.width / 2,
            y: old.midY - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        if let visible = panel.screen?.frame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        panel.setFrame(frame.integral, display: true, animate: false)
        bubble.apply(shape: shape)
    }

    private func persist() {
        var prefs = RecordingExtrasPreferences.load()
        prefs.webcamShape = shape
        prefs.webcamSize = size
        prefs.save()
    }

    private static func frameSize(shape: WebcamShape, size: WebcamSize) -> CGSize {
        let side = size.side
        switch shape {
        case .circle: return CGSize(width: side, height: side)
        case .roundedRect: return CGSize(width: (side * roundedAspect).rounded(), height: side)
        }
    }
}

/// Layer-backed view hosting the mirrored camera preview, clipped to the bubble shape.
@MainActor
private final class WebcamBubbleView: NSView {
    private static let borderWidth: CGFloat = 3
    private static let roundedRadiusRatio: CGFloat = 0.18

    private let previewLayer: AVCaptureVideoPreviewLayer
    var menuProvider: (@MainActor () -> NSMenu?)?

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        layer?.borderWidth = Self.borderWidth
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        layer?.insertSublayer(previewLayer, at: 0)
        setAccessibilityLabel(String(localized: "Webcam", bundle: .module))
        toolTip = String(localized: "Drag to move · Right-click for size and shape", bundle: .module)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(shape: WebcamShape) {
        let height = window?.frame.height ?? bounds.height
        switch shape {
        case .circle: layer?.cornerRadius = height / 2
        case .roundedRect: layer?.cornerRadius = height * Self.roundedRadiusRatio
        }
        needsLayout = true
    }
}
