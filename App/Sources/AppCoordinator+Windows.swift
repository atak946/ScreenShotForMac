import AppKit
import ShotBackdrop
import ShotCore
import ShotHistory
import ShotRecording
import ShotSettings
import ShotUpload
import ShotWorkflow
import SwiftUI

/// Settings, onboarding, history and combine windows.
extension AppCoordinator {
    func showSettings() {
        makeSettingsWindowIfNeeded().show()
    }

    /// Opens Settings at a specific pane (`SettingsPaneID` or an extra pane id).
    func showSettings(pane id: String) {
        makeSettingsWindowIfNeeded().show(pane: id)
    }

    private func makeSettingsWindowIfNeeded() -> SettingsWindowController {
        if let settingsWindow { return settingsWindow }
        let exporter = exporter
        let history = history
        let hud = hud
        let controller = SettingsWindowController(
            settings: settings,
            chooseSaveFolder: { _ = exporter.chooseSaveFolder() },
            saveFolderPath: { exporter.saveFolderDisplayPath() },
            clearHistory: {
                do {
                    try history.removeAll()
                    hud.showHUD(String(localized: "History cleared"))
                } catch {
                    hud.showError(error)
                }
            },
            openHistoryFolder: {
                NSWorkspace.shared.open(history.rootURL)
            },
            recordingExtras: AnyView(RecordingExtrasSettingsSection()),
            extraPanes: extraSettingsPanes()
        )
        settingsWindow = controller
        return controller
    }

    private func extraSettingsPanes() -> [SettingsExtraPane] {
        let workflows = WorkflowsSettingsPane(
            store: workflowStore,
            backdropPresetNames: backdropPresets.presets.map(\.name),
            onRun: { [weak self] workflow in self?.runWorkflow(workflow) }
        )
        return [
            SettingsExtraPane(
                id: Self.uploadSettingsPaneID,
                title: String(localized: "Upload"),
                symbol: "icloud.and.arrow.up",
                position: .before(SettingsPaneID.history),
                content: AnyView(UploadSettingsPane())
            ),
            SettingsExtraPane(
                id: Self.workflowsSettingsPaneID,
                title: String(localized: "Workflows"),
                symbol: "bolt.horizontal",
                position: .before(SettingsPaneID.history),
                content: AnyView(workflows)
            ),
        ]
    }

    func showHistory() {
        historyPresenter.showHistory { [weak self] capture in
            self?.openEditor(capture)
        }
    }

    /// Opens an empty Combine window (images are added by drag & drop or the add button).
    func showCombine(with captures: [CaptureResult] = []) {
        combine.open(with: captures) { [weak self] image, action in
            guard let self else { return }
            let scale = captures.first?.scale ?? NSScreen.main?.backingScaleFactor ?? 2
            let source = CaptureResult(image: image, scale: scale, screenRect: .zero, mode: .area)
            export(image, action: action, source: source)
        }
    }

    func showOnboarding() {
        let capture = capture
        let controller = OnboardingWindowController(
            onFinish: { [weak self] in self?.onboardingWindow = nil },
            requestScreenPermission: { capture.requestScreenRecordingPermission() },
            hasScreenPermission: { capture.hasScreenRecordingPermission() }
        )
        onboardingWindow = controller
        controller.show()
    }
}
