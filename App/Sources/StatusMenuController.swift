import AppKit
import ShotCore
import ShotRecording
import ShotSettings
import ShotWorkflow

/// Menu bar icon and its menu. Rebuilt on open so shortcut hints and recording state stay current.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private static let captureCommands: [AppCommand] = [
        .captureArea, .captureWindow, .captureFullscreen, .captureLastArea, .captureDelayed, .captureScrolling,
    ]
    private static let recordCommands: [AppCommand] = [.recordVideo, .recordGIF]
    private static let toolCommands: [AppCommand] = [.recognizeText, .pickColor, .scanQRCode, .measure]
    private static let clipboardCommands: [AppCommand] = [.openFromClipboard, .pinFromClipboard]
    private static let idleSymbol = "camera.viewfinder"
    private static let recordingSymbol = "record.circle.fill"
    private static let elapsedRefreshInterval: TimeInterval = 0.5

    private let statusItem: NSStatusItem
    private weak var coordinator: AppCoordinator?
    private weak var stopItem: NSMenuItem?
    private var elapsedTimer: Timer?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        updateStatusIcon(isRecording: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        coordinator.recorder.onRecordingStateChange = { [weak self] isRecording in
            self?.updateStatusIcon(isRecording: isRecording)
        }
        coordinator.recorder.onElapsedChange = { [weak self] elapsed in
            self?.updateElapsedTitle(elapsed)
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addRecordingControls(to: menu)
        addSection(String(localized: "Capture"), commands: Self.captureCommands, to: menu)
        if coordinator?.recorder.isRecording != true {
            addSection(String(localized: "Record"), commands: Self.recordCommands, to: menu)
        }
        addWorkflowsItem(to: menu)
        addSection(String(localized: "Tools"), commands: Self.toolCommands, to: menu)
        menu.addItem(actionItem(String(localized: "Combine Images…"), symbol: "square.grid.2x2", action: #selector(combineImages)))
        addSection(String(localized: "Clipboard"), commands: Self.clipboardCommands, to: menu)
        menu.addItem(actionItem(
            String(localized: "Upload Last Capture"), symbol: "icloud.and.arrow.up", action: #selector(uploadLastCapture)
        ))
        addHistorySection(to: menu)
        menu.addItem(.separator())
        menu.addItem(updatesItem())
        menu.addItem(settingsItem())
        menu.addItem(quitItem())
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard stopItem != nil else { return }
        let timer = Timer(timeInterval: Self.elapsedRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshElapsed() }
        }
        RunLoop.main.add(timer, forMode: .eventTracking)
        elapsedTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Status icon

    private func updateStatusIcon(isRecording: Bool) {
        guard let button = statusItem.button else { return }
        if isRecording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.white, DS.Palette.recording])
            let image = NSImage(systemSymbolName: Self.recordingSymbol, accessibilityDescription: String(localized: "Recording"))?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: Self.idleSymbol, accessibilityDescription: "ScreenShotForMac")
            image?.isTemplate = true
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    /// Shows the elapsed recording time next to the icon (e.g. "1:23"; paused adds a marker).
    private func updateElapsedTitle(_ elapsed: String) {
        guard let button = statusItem.button, coordinator?.recorder.isRecording == true else { return }
        let isPaused = coordinator?.recorder.isPaused == true
        button.imagePosition = .imageLeading
        button.attributedTitle = NSAttributedString(
            string: isPaused ? " \(elapsed) ⏸" : " \(elapsed)",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)]
        )
    }

    // MARK: - Sections

    private func addSection(_ title: String, commands: [AppCommand], to menu: NSMenu) {
        if menu.numberOfItems > 0 { menu.addItem(.separator()) }
        menu.addItem(.sectionHeader(title: title))
        commands.forEach { menu.addItem(item(for: $0)) }
    }

    private func addRecordingControls(to menu: NSMenu) {
        guard let coordinator, coordinator.recorder.isRecording else {
            stopItem = nil
            return
        }
        let stop = NSMenuItem(title: "", action: #selector(stopRecording), keyEquivalent: "")
        stop.target = self
        let config = NSImage.SymbolConfiguration(paletteColors: [.white, DS.Palette.recording])
        stop.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        menu.addItem(stop)
        stopItem = stop
        let isPaused = coordinator.recorder.isPaused
        menu.addItem(actionItem(
            isPaused ? String(localized: "Resume Recording") : String(localized: "Pause Recording"),
            symbol: isPaused ? "play.circle" : "pause.circle",
            action: #selector(togglePause)
        ))
        refreshElapsed()
    }

    private func addWorkflowsItem(to menu: NSMenu) {
        guard let coordinator else { return }
        menu.addItem(.separator())
        let root = NSMenuItem(title: String(localized: "Workflows"), action: nil, keyEquivalent: "")
        root.image = Self.symbol("bolt.horizontal")
        let submenu = NSMenu()
        for workflow in coordinator.workflowStore.workflows {
            let item = NSMenuItem(title: workflow.name, action: #selector(runWorkflow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = workflow.id.uuidString
            item.image = Self.symbol(workflow.symbol)
            if let shortcut = WorkflowHotkeys.shortcutDescription(for: workflow.id) {
                item.toolTip = shortcut
            }
            submenu.addItem(item)
        }
        if submenu.numberOfItems == 0 {
            let empty = NSMenuItem(title: String(localized: "No Workflows"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        submenu.addItem(.separator())
        submenu.addItem(actionItem(String(localized: "Edit Workflows…"), symbol: "slider.horizontal.3", action: #selector(editWorkflows)))
        root.submenu = submenu
        menu.addItem(root)
    }

    private func actionItem(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = Self.symbol(symbol)
        return item
    }

    private func refreshElapsed() {
        guard let stopItem else { return }
        let title = NSMutableAttributedString(
            string: String(localized: "Stop Recording"),
            attributes: [.foregroundColor: DS.Palette.recording, .font: NSFont.menuFont(ofSize: 0)]
        )
        if let elapsed = coordinator?.recorder.elapsedDescription {
            title.append(NSAttributedString(
                string: "   \(elapsed)",
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                ]
            ))
        }
        stopItem.attributedTitle = title
    }

    private func addHistorySection(to menu: NSMenu) {
        guard let coordinator else { return }
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: String(localized: "History")))
        let recent = NSMenuItem(title: String(localized: "Recent Captures"), action: nil, keyEquivalent: "")
        recent.image = Self.symbol("clock")
        recent.submenu = coordinator.historyPresenter.recentMenu { [weak coordinator] capture in
            coordinator?.openEditor(capture)
        }
        menu.addItem(recent)
        menu.addItem(item(for: .showHistory))
        if coordinator.pins.pinCount > 0 {
            let close = NSMenuItem(title: String(localized: "Close All Pins"), action: #selector(closeAllPins), keyEquivalent: "")
            close.target = self
            close.image = Self.symbol("pin.slash")
            menu.addItem(close)
        }
    }

    // MARK: - Items

    private func item(for command: AppCommand) -> NSMenuItem {
        let item = NSMenuItem(title: command.title, action: #selector(performCommand(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = command.rawValue
        item.image = Self.symbol(command.systemImage)
        // Display-only hint: the action itself is routed through the global hotkey.
        coordinator?.hotkeys?.applyShortcut(for: command, to: item)
        return item
    }

    private func settingsItem() -> NSMenuItem {
        let settings = item(for: .openSettings)
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        return settings
    }

    private func updatesItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: "Check for Updates…"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        item.target = self
        item.image = Self.symbol("arrow.triangle.2.circlepath")
        item.isEnabled = coordinator?.updater.canCheckForUpdates ?? false
        return item
    }

    @objc
    private func checkForUpdates() {
        coordinator?.updater.checkForUpdates()
    }

    private func quitItem() -> NSMenuItem {
        let quit = NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        quit.image = Self.symbol("power")
        return quit
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    // MARK: - Actions

    @objc
    private func stopRecording() {
        coordinator?.recorder.stop()
    }

    @objc
    private func togglePause() {
        coordinator?.recorder.togglePause()
    }

    @objc
    private func combineImages() {
        coordinator?.showCombine()
    }

    @objc
    private func uploadLastCapture() {
        coordinator?.uploadLastCapture()
    }

    @objc
    private func runWorkflow(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw) else { return }
        coordinator?.runWorkflow(id: id)
    }

    @objc
    private func editWorkflows() {
        coordinator?.showSettings(pane: AppCoordinator.workflowsSettingsPaneID)
    }

    @objc
    private func closeAllPins() {
        coordinator?.pins.closeAllPins()
    }

    @objc
    private func performCommand(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let command = AppCommand(rawValue: raw) else { return }
        coordinator?.perform(command)
    }
}
