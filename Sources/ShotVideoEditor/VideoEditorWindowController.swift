import AppKit
import ShotCore
import SwiftUI

/// One trim-editor window: hosts `VideoEditorView`, runs the save flow.
@MainActor
final class VideoEditorWindowController: NSObject, NSWindowDelegate {
    private static let defaultSize = CGSize(width: 980, height: 660)

    let sourceURL: URL
    private let model: VideoEditorModel
    private let saver = VideoSaveCoordinator()
    private let onSaved: @MainActor (URL) -> Void
    private let onClose: @MainActor (VideoEditorWindowController) -> Void
    private var window: NSWindow?
    private var errorMessage: String? {
        didSet { renderErrorBinding() }
    }

    private var hostingView: NSHostingView<VideoEditorView>?

    init(
        url: URL,
        onSaved: @escaping @MainActor (URL) -> Void,
        onClose: @escaping @MainActor (VideoEditorWindowController) -> Void
    ) {
        sourceURL = url
        model = VideoEditorModel(url: url)
        self.onSaved = onSaved
        self.onClose = onClose
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        WindowActivation.present(window)
    }

    // MARK: - Window

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = sourceURL.lastPathComponent
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 760, height: 480)
        window.delegate = self
        let hosting = NSHostingView(rootView: makeRootView())
        hostingView = hosting
        window.contentView = hosting
        window.center()
        window.setFrameAutosaveName("VideoEditorWindow")
        return window
    }

    private func makeRootView() -> VideoEditorView {
        VideoEditorView(
            model: model,
            actions: VideoEditorActions(
                save: { [weak self] in self?.save() },
                cancelExport: { [weak self] in self?.saver.cancel() },
                close: { [weak self] in self?.window?.close() }
            ),
            errorMessage: Binding(
                get: { [weak self] in self?.errorMessage },
                set: { [weak self] in self?.errorMessage = $0 }
            )
        )
    }

    private func renderErrorBinding() {
        hostingView?.rootView = makeRootView()
    }

    func windowWillClose(_ notification: Notification) {
        saver.cancel()
        model.tearDown()
        onClose(self)
    }

    // MARK: - Save

    private func save() {
        guard !saver.isRunning, model.phase == .ready else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await saver.save(model)
                onSaved(url)
                window?.close()
            } catch is CancellationError {
                Log.videoEditor.info("Video export cancelled")
            } catch {
                Log.videoEditor.error("Video export failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }
}
