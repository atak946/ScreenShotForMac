@preconcurrency import AVFoundation
import Observation
import ShotCore

/// State of one trim-editor window: playback, trim range and export options.
@MainActor
@Observable
final class VideoEditorModel {
    enum Phase: Equatable {
        case loading
        case ready
        case exporting(progress: Double)
        case failed(String)
    }

    static let minimumSpan: Double = 0.1
    private static let thumbnailCount = 14
    private static let thumbnailHeight: CGFloat = 96
    private static let timescale: CMTimeScale = 600
    private static let observerInterval = CMTime(value: 1, timescale: 30)

    let sourceURL: URL
    let player: AVPlayer
    private(set) var phase: Phase = .loading
    private(set) var duration: Double = 0
    private(set) var hasAudio = false
    private(set) var thumbnails: [CGImage] = []
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private(set) var inPoint: Double = 0
    private(set) var outPoint: Double = 0

    var isMuted = false { didSet { player.isMuted = isMuted } }
    var speed: PlaybackSpeed = .normal { didSet { if isPlaying { player.rate = Float(speed.rawValue) } } }
    var format: VideoOutputFormat = .mp4 { didSet { if !canOverwrite { saveMode = .copy } } }
    var gifFramesPerSecond = 15
    var gifWidth: GIFWidth = .w640
    var saveMode: VideoSaveMode = .copy

    @ObservationIgnored private var timeObserver: Any?

    init(url: URL) {
        sourceURL = url
        player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
    }

    /// Overwriting is only offered when the output keeps the source's file type.
    var canOverwrite: Bool {
        sourceURL.pathExtension.lowercased() == format.fileExtension
    }

    var isExporting: Bool {
        if case .exporting = phase { return true }
        return false
    }

    var trimmedDuration: Double { max(0, outPoint - inPoint) / speed.rawValue }

    // MARK: - Loading

    func load() async {
        let asset = AVURLAsset(url: sourceURL)
        do {
            let seconds = try await asset.load(.duration).seconds
            guard seconds.isFinite, seconds > 0,
                  try await !asset.loadTracks(withMediaType: .video).isEmpty else {
                phase = .failed(VideoEditorError.unreadable.localizedDescription)
                return
            }
            hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
            duration = seconds
            outPoint = seconds
            phase = .ready
            installTimeObserver()
        } catch {
            Log.videoEditor.error("Video load failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed(VideoEditorError.unreadable.localizedDescription)
            return
        }
        thumbnails = await ThumbnailLoader.load(
            url: sourceURL, duration: duration, count: Self.thumbnailCount, height: Self.thumbnailHeight
        )
    }

    func tearDown() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }

    // MARK: - Playback

    func togglePlay() {
        guard phase == .ready else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }
        if currentTime >= outPoint - 0.05 || currentTime < inPoint {
            seek(to: inPoint)
        }
        player.rate = Float(speed.rawValue)
        isPlaying = true
    }

    func scrub(to seconds: Double) {
        seek(to: min(max(seconds, inPoint), outPoint))
    }

    func setInPoint(_ seconds: Double) {
        inPoint = min(max(0, seconds), outPoint - Self.minimumSpan)
        seek(to: inPoint)
    }

    func setOutPoint(_ seconds: Double) {
        outPoint = max(min(duration, seconds), inPoint + Self.minimumSpan)
        seek(to: outPoint)
    }

    private func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: Self.timescale), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: Self.observerInterval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.playerDidAdvance(to: time.seconds) }
        }
    }

    private func playerDidAdvance(to seconds: Double) {
        guard isPlaying else { return }
        currentTime = seconds
        if seconds >= outPoint - 0.01 || player.rate == 0 {
            player.pause()
            isPlaying = false
            seek(to: outPoint)
        }
    }

    // MARK: - Export

    func makeExportRequest(outputURL: URL) -> VideoExportRequest {
        VideoExportRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            start: inPoint,
            end: outPoint,
            speed: speed.rawValue,
            removesAudio: isMuted || !hasAudio,
            gifFramesPerSecond: gifFramesPerSecond,
            gifMaxWidth: gifWidth.maxWidth
        )
    }

    func pauseForExport() {
        player.pause()
        isPlaying = false
    }

    func setPhase(_ newPhase: Phase) {
        phase = newPhase
    }
}
