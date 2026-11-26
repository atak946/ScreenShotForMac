import AppKit
import CoreMedia
import CoreVideo
import ShotCore

/// One recording from the moment capture starts until the file is written.
/// Owns every window and the stream; all are torn down on every path.
@MainActor
final class RecordingSession {
    /// Optional overlays that are part of the recorded image.
    struct Extras {
        /// Already visible (shown before the countdown so it can be positioned).
        var webcam: WebcamOverlay?
        var showsKeystrokes = false
        var keystrokesShortcutsOnly = true
    }

    private enum Outcome {
        case stop
        case cancel
        case failure(Error)
    }

    private static let tickInterval: TimeInterval = 0.5

    private let target: RecordingTarget
    private let options: RecordingOptions
    private let outputURL: URL
    private var border: RecordingBorderWindow?
    private var highlighter: ClickHighlighter?
    private var keystrokes: KeystrokeOverlay?
    private var webcam: WebcamOverlay?
    private let extras: Extras
    private var controls: RecordingControls?
    private var capture: StreamCapture?
    private var timer: Timer?
    private var clock = RecordingClock()
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var pendingOutcome: Outcome?

    /// Called on every clock tick with the elapsed time and the paused flag.
    var onTick: (@MainActor (TimeInterval, Bool) -> Void)?

    init(target: RecordingTarget, options: RecordingOptions, extras: Extras, outputURL: URL) {
        self.target = target
        self.options = options
        self.extras = extras
        webcam = extras.webcam
        self.outputURL = outputURL
    }

    var isPaused: Bool { clock.isPaused }

    /// Records until stopped. Returns nil when the user discarded the recording.
    func run() async throws -> RecordingResult? {
        defer { tearDownUI() }
        showOverlays()
        let plan = makePlan()
        let sink = try makeSink(plan: plan)
        let capture = StreamCapture(sink: sink) { [weak self] error in
            Task { @MainActor in self?.handleStreamFailure(error) }
        }
        self.capture = capture
        do {
            try await capture.start(plan: plan)
        } catch {
            sink.discard()
            throw error
        }
        startClock()

        let outcome = await waitForOutcome()
        let endTime = await capture.stop()
        tearDownUI()
        return try await complete(outcome, sink: sink, endTime: endTime, plan: plan)
    }

    /// Recorded time so far, excluding pauses.
    var elapsed: TimeInterval { clock.elapsed() }

    func stop() { resolve(.stop) }
    func cancel() { resolve(.cancel) }

    func togglePause() {
        guard let capture, continuation != nil else { return }
        if clock.isPaused {
            capture.resume()
            clock = clock.resumed()
        } else {
            capture.pause()
            clock = clock.paused()
        }
        tick()
    }

    // MARK: - Lifecycle

    private func showOverlays() {
        let border = RecordingBorderWindow(target: target)
        border.show()
        self.border = border

        if options.highlightClicks {
            let highlighter = ClickHighlighter(rect: target.rect)
            highlighter.show()
            self.highlighter = highlighter
        }

        if extras.showsKeystrokes {
            let keystrokes = KeystrokeOverlay(rect: target.rect, shortcutsOnly: extras.keystrokesShortcutsOnly)
            keystrokes.show()
            self.keystrokes = keystrokes
        }

        let controls = RecordingControls(actions: RecordingControlActions(
            onStop: { [weak self] in self?.stop() },
            onTogglePause: { [weak self] in self?.togglePause() },
            onCancel: { [weak self] in self?.cancel() }
        ))
        controls.show(around: target)
        self.controls = controls
    }

    private func startClock() {
        clock = RecordingClock()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let elapsed = clock.elapsed()
        controls?.update(elapsed: elapsed, isPaused: clock.isPaused)
        onTick?(elapsed, clock.isPaused)
    }

    private func waitForOutcome() async -> Outcome {
        if let pendingOutcome { return pendingOutcome }
        return await withCheckedContinuation { self.continuation = $0 }
    }

    private func resolve(_ outcome: Outcome) {
        guard let continuation else {
            if pendingOutcome == nil { pendingOutcome = outcome }
            return
        }
        self.continuation = nil
        continuation.resume(returning: outcome)
    }

    private func handleStreamFailure(_ error: Error) {
        if StreamCapture.isUserStopped(error) {
            Log.recording.info("Recording stopped from the system UI")
            resolve(.stop)
        } else {
            resolve(.failure(StreamCapture.mapError(error)))
        }
    }

    private func tearDownUI() {
        timer?.invalidate()
        timer = nil
        border?.close()
        border = nil
        highlighter?.close()
        highlighter = nil
        keystrokes?.close()
        keystrokes = nil
        webcam?.close()
        webcam = nil
        controls?.close()
        controls = nil
    }

    private func complete(
        _ outcome: Outcome,
        sink: SampleSink,
        endTime: CMTime,
        plan: CapturePlan
    ) async throws -> RecordingResult? {
        let duration: TimeInterval
        switch outcome {
        case .cancel:
            sink.discard()
            Log.recording.info("Recording discarded")
            return nil
        case .stop:
            duration = try await sink.finish(endTime: endTime)
        case let .failure(streamError):
            // Keep whatever was captured before the stream failed, if anything.
            do {
                duration = try await sink.finish(endTime: endTime)
                Log.recording.error("Stream failed, partial recording saved: \(streamError.localizedDescription, privacy: .public)")
            } catch {
                Log.recording.error("Partial recording could not be saved: \(error.localizedDescription, privacy: .public)")
                throw streamError
            }
        }
        Log.recording.info("Recording saved (\(duration, format: .fixed(precision: 1)) s)")
        return RecordingResult(
            fileURL: outputURL,
            format: options.format,
            duration: duration,
            pixelSize: CGSize(width: plan.outputWidth, height: plan.outputHeight)
        )
    }

    // MARK: - Configuration

    private func makePlan() -> CapturePlan {
        let isGIF = options.format == .gif
        let size = target.outputPixelSize(maxWidth: isGIF ? RecordingTarget.gifMaxWidth : nil)
        let fps = min(max(options.framesPerSecond, 1), isGIF ? 30 : 60)
        return CapturePlan(
            target: target,
            outputWidth: size.width,
            outputHeight: size.height,
            framesPerSecond: fps,
            showsCursor: options.showCursor,
            capturesSystemAudio: !isGIF && options.captureSystemAudio,
            capturesMicrophone: !isGIF && options.captureMicrophone,
            pixelFormat: isGIF ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            includedOwnWindowIDs: [highlighter?.windowID, keystrokes?.windowID, webcam?.windowID].compactMap(\.self)
        )
    }

    private func makeSink(plan: CapturePlan) throws -> SampleSink {
        switch options.format {
        case .gif:
            return try GIFWriter(url: outputURL, framesPerSecond: plan.framesPerSecond)
        case .mp4:
            var sources = Set<AudioSource>()
            if plan.capturesSystemAudio { sources.insert(.system) }
            if plan.capturesMicrophone { sources.insert(.microphone) }
            return try MovieWriter(
                url: outputURL,
                width: plan.outputWidth,
                height: plan.outputHeight,
                framesPerSecond: plan.framesPerSecond,
                audioSources: sources
            )
        }
    }
}
