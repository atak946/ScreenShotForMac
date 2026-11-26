import AppKit
import AVFoundation
import CoreGraphics
import ShotCore

/// ScreenCaptureKit based screen recorder producing MP4 (H.264 / HEVC + AAC) or GIF files.
///
/// Flow: selection overlay (area / window / full screen) → 3-2-1 countdown →
/// recording with a dashed border and floating controls (the App's menu bar item shows state + Stop).
/// Optional extras: webcam bubble and keystroke display, both included in the capture.
@MainActor
public final class ScreenRecorder: ScreenRecording {
    private static let countdownSeconds = 3

    private let settings: AppSettings
    private var isBusy = false
    private var countdown: CountdownHUD?
    private var session: RecordingSession?

    /// Called on the main actor whenever `isRecording` flips (menu bar icon, menus).
    public var onRecordingStateChange: (@MainActor (Bool) -> Void)?

    public private(set) var isRecording = false {
        didSet {
            guard oldValue != isRecording else { return }
            onRecordingStateChange?(isRecording)
        }
    }

    /// Elapsed time of the active recording (pauses excluded) as `m:ss`; nil when idle.
    public var elapsedDescription: String? {
        guard isRecording, let session else { return nil }
        return RecordingGeometry.formatElapsed(session.elapsed)
    }

    /// Called on the main actor about twice a second while recording with the elapsed
    /// time as `m:ss` (pauses excluded), e.g. for the App's menu bar title.
    public var onElapsedChange: (@MainActor (String) -> Void)?

    /// Whether the active recording is paused; false when idle.
    public var isPaused: Bool {
        session?.isPaused ?? false
    }

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public func record(options: RecordingOptions) async throws -> RecordingResult? {
        guard !isBusy else {
            Log.recording.info("Ignoring record request: a recording flow is already active")
            return nil
        }
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        isBusy = true
        var webcam: WebcamOverlay?
        defer {
            webcam?.close()
            isBusy = false
            isRecording = false
            countdown = nil
            session = nil
        }

        var prefs = RecordingExtrasPreferences.load()
        guard let (target, toggles) = await selectTarget(options: options, prefs: prefs) else {
            Log.recording.info("Recording cancelled during selection")
            return nil
        }
        persist(toggles, format: options.format, prefs: &prefs)
        let effective = await resolveMicrophone(in: options.applying(toggles))
        webcam = await makeWebcam(enabled: toggles.camera, prefs: prefs, rect: target.rect)

        let hud = CountdownHUD()
        countdown = hud
        guard await hud.run(seconds: Self.countdownSeconds, centeredOn: target.rect) else {
            Log.recording.info("Recording cancelled during countdown")
            return nil
        }
        countdown = nil

        let extras = RecordingSession.Extras(
            webcam: webcam,
            showsKeystrokes: toggles.keystrokes && RecordingPermissions.isAccessibilityTrusted,
            keystrokesShortcutsOnly: prefs.keystrokesShortcutsOnly
        )
        return try await runSession(target: target, options: effective, extras: extras)
    }

    public func stop() {
        countdown?.cancel()
        session?.stop()
    }

    /// Pauses or resumes the active recording (no-op when idle).
    public func togglePause() {
        session?.togglePause()
    }

    // MARK: - Flow steps

    private func selectTarget(
        options: RecordingOptions,
        prefs: RecordingExtrasPreferences
    ) async -> (RecordingTarget, RecordingToggles)? {
        let initial = RecordingToggles(
            camera: prefs.showWebcam,
            microphone: options.captureMicrophone,
            systemAudio: options.captureSystemAudio,
            clicks: options.highlightClicks,
            keystrokes: prefs.showKeystrokes && RecordingPermissions.isAccessibilityTrusted
        )
        let toolbar = RecordingOptionsToolbar(toggles: initial, allowsAudio: options.format == .mp4)
        guard let target = await RecordingSelectionController(toolbar: toolbar).run() else { return nil }
        return (target, toolbar.toggles)
    }

    /// Remembers the toolbar choices for the next recording.
    private func persist(_ toggles: RecordingToggles, format: RecordingFormat, prefs: inout RecordingExtrasPreferences) {
        if format == .mp4 {
            settings.recordMicrophone = toggles.microphone
            settings.recordSystemAudio = toggles.systemAudio
        }
        settings.recordHighlightClicks = toggles.clicks
        prefs.showWebcam = toggles.camera
        if RecordingPermissions.isAccessibilityTrusted {
            prefs.showKeystrokes = toggles.keystrokes
        }
        prefs.save()
    }

    /// Camera permission is requested only here, when the webcam is enabled.
    private func makeWebcam(enabled: Bool, prefs: RecordingExtrasPreferences, rect: CGRect) async -> WebcamOverlay? {
        guard enabled else { return nil }
        guard await RecordingPermissions.requestCameraAccess() else {
            Log.recording.info("Camera access denied; recording without webcam")
            return nil
        }
        guard let overlay = WebcamOverlay(prefs: prefs) else { return nil }
        overlay.show(in: rect)
        return overlay
    }

    private func runSession(
        target: RecordingTarget,
        options: RecordingOptions,
        extras: RecordingSession.Extras
    ) async throws -> RecordingResult? {
        let url = try RecordingFileLocation.makeURL(format: options.format)
        let session = RecordingSession(target: target, options: options, extras: extras, outputURL: url)
        session.onTick = { [weak self] elapsed, _ in
            self?.onElapsedChange?(RecordingGeometry.formatElapsed(elapsed))
        }
        self.session = session
        isRecording = true
        Log.recording.info("Recording \(options.format.rawValue, privacy: .public) to \(url.lastPathComponent, privacy: .public)")
        return try await session.run()
    }

    // MARK: - Microphone

    /// Returns options with the microphone disabled when unsupported or not authorized.
    private func resolveMicrophone(in options: RecordingOptions) async -> RecordingOptions {
        guard options.format == .mp4, options.captureMicrophone else { return options }
        guard #available(macOS 15.0, *) else {
            Log.recording.info("Microphone capture requires macOS 15; recording without microphone")
            return options.withMicrophone(false)
        }
        let granted = await Self.requestMicrophoneAccess()
        if !granted {
            Log.recording.info("Microphone access denied; recording without microphone")
        }
        return options.withMicrophone(granted)
    }

    private nonisolated static func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}

extension RecordingOptions {
    /// Options with the selection-toolbar switches applied (audio only for MP4).
    fileprivate func applying(_ toggles: RecordingToggles) -> RecordingOptions {
        let isVideo = format == .mp4
        return RecordingOptions(
            format: format,
            captureSystemAudio: isVideo && toggles.systemAudio,
            captureMicrophone: isVideo && toggles.microphone,
            showCursor: showCursor,
            highlightClicks: toggles.clicks,
            framesPerSecond: framesPerSecond
        )
    }

    fileprivate func withMicrophone(_ enabled: Bool) -> RecordingOptions {
        RecordingOptions(
            format: format,
            captureSystemAudio: captureSystemAudio,
            captureMicrophone: enabled,
            showCursor: showCursor,
            highlightClicks: highlightClicks,
            framesPerSecond: framesPerSecond
        )
    }
}
