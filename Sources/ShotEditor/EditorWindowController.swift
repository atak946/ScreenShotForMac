import AppKit
import ShotCore
import SwiftUI

/// One editor window per capture.
@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private static let minimumSize = CGSize(width: 720, height: 480)
    private static let maxScreenFraction: CGFloat = 0.85
    private static let styleBarBottomInset: CGFloat = 10
    private static let toastTopInset: CGFloat = 12

    private let viewModel: EditorViewModel
    private let onClose: () -> Void

    init(
        capture: CaptureResult,
        settings: AppSettings,
        extraActions: EditorExtraActions,
        onExport: @escaping @MainActor (CGImage, ExportAction) -> Void,
        onClose: @escaping () -> Void
    ) {
        let document = EditorDocument(baseImage: capture.image, scale: capture.scale)
        viewModel = EditorViewModel(document: document, onExport: onExport)
        self.onClose = onClose

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.minimumSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Title stays set for Mission Control / Window menu, but is not drawn.
        window.title = Self.title(width: capture.image.width, height: capture.image.height)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = DS.Palette.canvas
        window.isReleasedWhenClosed = false
        window.minSize = Self.minimumSize
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self

        let canvas = CanvasView(viewModel: viewModel)
        window.contentView = makeContentView(canvas: canvas)
        window.initialFirstResponder = canvas
        viewModel.onRequestClose = { [weak window] in window?.performClose(nil) }
        viewModel.shouldCloseAfterSave = { [weak settings] in settings?.editorCloseAfterSave ?? true }
        Self.wire(extraActions, capture: capture, into: viewModel)
        viewModel.onOutputSizeChange = { [weak window] size in
            window?.title = Self.title(width: Int(size.width), height: Int(size.height))
        }
        sizeWindow(window, imagePointSize: document.bounds.size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        guard let window else { return }
        WindowActivation.present(window)
        centerTrafficLights()
        if let canvas = window.initialFirstResponder {
            window.makeFirstResponder(canvas)
        }
    }

    /// Mission Control / Window menu title; follows crop, padding and rotation.
    private static func title(width: Int, height: Int) -> String {
        String(localized: "Screenshot – \(width)×\(height)", bundle: .module)
    }

    /// Wraps flattened images into a `CaptureResult` that mirrors the original capture.
    private static func wire(_ actions: EditorExtraActions, capture: CaptureResult, into viewModel: EditorViewModel) {
        let makeCapture: (CGImage) -> CaptureResult = { image in
            CaptureResult(
                image: image, scale: capture.scale, screenRect: capture.screenRect, mode: capture.mode,
                capturedAt: capture.capturedAt, sourceAppName: capture.sourceAppName
            )
        }
        if let onBackdrop = actions.onBackdrop {
            viewModel.onBackdrop = { image in onBackdrop(makeCapture(image)) }
        }
        if let onPin = actions.onPin {
            viewModel.onPin = { image in onPin(makeCapture(image)) }
        }
        if let onUpload = actions.onUpload {
            viewModel.onUpload = { image in onUpload(makeCapture(image)) }
        }
        viewModel.sensitiveDataDetector = actions.sensitiveDataDetector
    }

    private func makeContentView(canvas: CanvasView) -> NSView {
        let container = NSView()
        let toolbar = NSHostingView(rootView: EditorToolbarView(viewModel: viewModel))
        toolbar.sizingOptions = []
        let styleBar = StyleBarHostingView(viewModel: viewModel)
        let toast = PassthroughHostingView(rootView: EditorToastView(viewModel: viewModel))
        toast.sizingOptions = [.intrinsicContentSize]
        [canvas, toolbar, styleBar, toast].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: container.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: EditorToolbarView.height),
            canvas.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            styleBar.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            styleBar.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -Self.styleBarBottomInset),
            toast.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            toast.topAnchor.constraint(equalTo: canvas.topAnchor, constant: Self.toastTopInset),
        ])
        return container
    }

    private func centerTrafficLights() {
        guard let window else { return }
        TrafficLights.center(in: window, barHeight: EditorToolbarView.height)
    }

    /// Sizes the window to the image (points) up to 85% of the screen, then centers it.
    private func sizeWindow(_ window: NSWindow, imagePointSize: CGSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let desired = CGSize(
            width: imagePointSize.width + CanvasLayout.padding * 2,
            height: imagePointSize.height + CanvasLayout.padding + CanvasLayout.bottomPadding + EditorToolbarView.height
        )
        let size = CGSize(
            width: min(max(desired.width, Self.minimumSize.width), visible.width * Self.maxScreenFraction),
            height: min(max(desired.height, Self.minimumSize.height), visible.height * Self.maxScreenFraction)
        )
        window.setContentSize(size)
        let frame = window.frame
        window.setFrameOrigin(CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2))
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) { centerTrafficLights() }
    func windowDidExitFullScreen(_ notification: Notification) { centerTrafficLights() }
    func windowDidBecomeKey(_ notification: Notification) { centerTrafficLights() }

    func windowWillClose(_ notification: Notification) {
        Log.editor.debug("Editor window closed")
        onClose()
    }
}
