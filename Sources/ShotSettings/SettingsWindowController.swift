import AppKit
import ShotCore
import SwiftUI

/// Hosts the sidebar-style Settings in a single reusable, fixed-size window.
@MainActor
public final class SettingsWindowController {
    private static let defaultSize = CGSize(width: 780, height: 560)
    private static let minimumSize = CGSize(width: 720, height: 480)
    private static let autosaveName = "SettingsWindow.v2"

    private var window: NSWindow?
    private let context: SettingsContext
    private let extraPanes: [SettingsExtraPane]
    private var model: SettingsNavigationModel?

    public init(
        settings: AppSettings = .shared,
        chooseSaveFolder: @escaping @MainActor () -> Void,
        saveFolderPath: @escaping @MainActor () -> String,
        clearHistory: @escaping @MainActor () -> Void = {},
        openHistoryFolder: @escaping @MainActor () -> Void = {},
        recordingExtras: AnyView? = nil,
        extraPanes: [SettingsExtraPane] = []
    ) {
        context = SettingsContext(
            settings: settings,
            chooseSaveFolder: chooseSaveFolder,
            saveFolderPath: saveFolderPath,
            clearHistory: clearHistory,
            openHistoryFolder: openHistoryFolder,
            recordingExtras: recordingExtras
        )
        self.extraPanes = extraPanes
    }

    public func show() {
        let window = window ?? makeWindow()
        self.window = window
        WindowActivation.present(window)
    }

    /// Shows the window with the pane `id` selected (a `SettingsPaneID` or an extra pane's id).
    public func show(pane id: String) {
        show()
        model?.select(id)
    }

    public func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let model = SettingsNavigationModel(entries: SettingsEntry.entries(context: context, extras: extraPanes))
        self.model = model
        let hosting = NSHostingController(rootView: SettingsRootView(model: model))
        // The window size is owned by AppKit; pane content never resizes it.
        hosting.sizingOptions = []
        hosting.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenNone)
        window.contentMinSize = Self.minimumSize
        window.setContentSize(Self.defaultSize)
        window.center()
        window.setFrameAutosaveName(Self.autosaveName)
        window.title = model.selectedEntry?.title ?? ""
        model.onTitleChange = { [weak window] title in window?.title = title }
        return window
    }
}
