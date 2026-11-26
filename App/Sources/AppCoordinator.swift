import AppKit
import ShotBackdrop
import ShotCapture
import ShotCombine
import ShotCore
import ShotEditor
import ShotExport
import ShotHistory
import ShotMeasure
import ShotPin
import ShotRecording
import ShotScrolling
import ShotSettings
import ShotTools
import ShotUpload
import ShotVideoEditor
import ShotWorkflow

/// Composition root: owns every service and routes commands between modules.
/// Flows live in the `AppCoordinator+*.swift` extensions.
@MainActor
final class AppCoordinator: CommandHandling {
    let settings: AppSettings
    let capture: CaptureService
    let scrolling: ScrollingCaptureService
    let recorder: ScreenRecorder
    let exporter: ExportService
    let quickAccess: QuickAccessPresenter
    let textRecognizer: TextRecognizer
    let colorPicker: ColorPicker
    let measureTool: MeasureTool
    let pins: PinPresenter
    let backdrop: BackdropPresenter
    let history: HistoryStore
    let historyPresenter: HistoryPresenter
    let hud: HUDController
    let updater = UpdaterController()
    let uploader: UploadService
    let workflowStore: WorkflowStore
    let videoEditor: VideoEditorPresenter
    let combine: CombinePresenter
    let sensitiveDetector: SensitiveDataDetector
    let backdropPresets: BackdropPresetStore
    let wallpaper: WallpaperProvider
    private(set) var editor: EditorPresenter!
    private(set) var workflowRunner: WorkflowRunner!
    private(set) var hotkeys: HotkeyManager?
    private(set) var workflowHotkeys: WorkflowHotkeys?
    var settingsWindow: SettingsWindowController?
    var onboardingWindow: OnboardingWindowController?
    /// Most recent capture of this session (for "Upload Last Capture"); history is the fallback.
    var lastCapture: CaptureResult?
    private(set) var isBusy = false

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let capture = CaptureService(settings: settings)
        let exporter = ExportService(settings: settings)
        let history = HistoryStore(settings: settings)
        self.capture = capture
        self.exporter = exporter
        self.history = history
        scrolling = ScrollingCaptureService(settings: settings)
        recorder = ScreenRecorder(settings: settings)
        quickAccess = QuickAccessPresenter(settings: settings)
        textRecognizer = TextRecognizer()
        colorPicker = ColorPicker(snapshotProvider: { try await capture.snapshotAllDisplays() }, settings: settings)
        measureTool = MeasureTool(
            snapshotProvider: { try await capture.snapshotAllDisplays() },
            copyText: { exporter.copyText($0) }
        )
        pins = PinPresenter()
        backdrop = BackdropPresenter()
        historyPresenter = HistoryPresenter(store: history)
        hud = HUDController()
        uploader = UploadService()
        workflowStore = WorkflowStore()
        videoEditor = VideoEditorPresenter()
        combine = CombinePresenter()
        let detector = SensitiveDataDetector()
        sensitiveDetector = detector
        backdropPresets = BackdropPresetStore()
        wallpaper = WallpaperProvider()
        editor = EditorPresenter(
            settings: settings,
            onBackdrop: { [weak self] in self?.openBackdrop($0) },
            onPin: { [weak self] in self?.pins.pin($0, at: nil) },
            onUpload: { [weak self] in self?.uploadCapture($0) },
            sensitiveDataDetector: detector
        )
        workflowRunner = WorkflowRunner(environment: self)
    }

    func start() {
        updater.start()
        let hotkeys = HotkeyManager(handler: self)
        hotkeys.start()
        self.hotkeys = hotkeys
        let workflowHotkeys = WorkflowHotkeys { [weak self] id in self?.runWorkflow(id: id) }
        workflowHotkeys.observe(workflowStore)
        self.workflowHotkeys = workflowHotkeys
        if let hint = hotkeys.shortcutDescription(for: .captureArea) {
            historyPresenter.captureShortcutHint = hint
        }
        if !settings.hasCompletedOnboarding || !capture.hasScreenRecordingPermission() {
            showOnboarding()
        }
    }

    // MARK: - CommandHandling

    func perform(_ command: AppCommand) {
        switch command {
        case .captureArea: runExclusive { try await self.deliver(self.capture.capture(.area)) }
        case .captureWindow: runExclusive { try await self.deliver(self.capture.capture(.window)) }
        case .captureFullscreen: runExclusive { try await self.deliver(self.capture.capture(.fullscreen)) }
        case .captureLastArea: runExclusive { try await self.deliver(self.capture.captureLastArea()) }
        case .captureDelayed:
            runExclusive { try await self.deliver(self.capture.captureDelayed(.area, seconds: self.settings.captureDelaySeconds)) }
        case .captureScrolling: runExclusive { try await self.deliver(self.scrolling.captureScrolling()) }
        case .recordVideo: toggleRecording(.mp4)
        case .recordGIF: toggleRecording(.gif)
        case .recognizeText: runExclusive { try await self.recognizeText() }
        case .scanQRCode: runExclusive { try await self.scanCodes() }
        case .pickColor: runExclusive { try await self.pickColor() }
        case .measure: runExclusive { try await self.measureTool.startMeasuring() }
        case .pinFromClipboard: pinFromClipboard()
        case .openFromClipboard: openFromClipboard()
        case .showHistory: showHistory()
        case .openSettings: showSettings()
        }
    }

    /// Prevents overlapping overlays when hotkeys are pressed repeatedly.
    func runExclusive(_ work: @escaping @MainActor () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                try await work()
            } catch CaptureError.permissionDenied {
                hud.showError(CaptureError.permissionDenied)
                capture.requestScreenRecordingPermission()
            } catch {
                hud.showError(error)
            }
        }
    }
}
