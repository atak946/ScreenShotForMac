import AppKit
import CoreGraphics
import Foundation

// MARK: - Screen recording (implemented in ShotRecording)

public enum RecordingFormat: String, Sendable, CaseIterable, Codable, Identifiable {
    case mp4
    case gif
    public var id: String { rawValue }
}

public struct RecordingOptions: Sendable, Equatable {
    public let format: RecordingFormat
    public let captureSystemAudio: Bool
    public let captureMicrophone: Bool
    public let showCursor: Bool
    public let highlightClicks: Bool
    public let framesPerSecond: Int

    public init(
        format: RecordingFormat,
        captureSystemAudio: Bool = false,
        captureMicrophone: Bool = false,
        showCursor: Bool = true,
        highlightClicks: Bool = false,
        framesPerSecond: Int = 30
    ) {
        self.format = format
        self.captureSystemAudio = captureSystemAudio
        self.captureMicrophone = captureMicrophone
        self.showCursor = showCursor
        self.highlightClicks = highlightClicks
        self.framesPerSecond = framesPerSecond
    }
}

public struct RecordingResult: Sendable {
    public let fileURL: URL
    public let format: RecordingFormat
    public let duration: TimeInterval
    public let pixelSize: CGSize
    public init(fileURL: URL, format: RecordingFormat, duration: TimeInterval, pixelSize: CGSize) {
        self.fileURL = fileURL
        self.format = format
        self.duration = duration
        self.pixelSize = pixelSize
    }
}

@MainActor
public protocol ScreenRecording: AnyObject {
    var isRecording: Bool { get }
    /// Lets the user pick an area / window / screen, records until the user stops
    /// (menu bar stop button, control panel or the same hotkey via `stop()`).
    /// Returns nil when cancelled before recording started.
    func record(options: RecordingOptions) async throws -> RecordingResult?
    /// Stops an active recording; `record` then returns.
    func stop()
}

// MARK: - Scrolling capture (implemented in ShotScrolling)

@MainActor
public protocol ScrollingCapturing: AnyObject {
    /// User selects an area, then scrolls (or auto-scroll); frames are stitched into one tall image.
    /// Returns nil when cancelled.
    func captureScrolling() async throws -> CaptureResult?
}

// MARK: - Pin (implemented in ShotPin)

@MainActor
public protocol PinPresenting: AnyObject {
    /// Shows the image as an always-on-top floating window at `screenRect` (or centered if nil).
    func pin(_ capture: CaptureResult, at screenRect: CGRect?)
    func closeAllPins()
    var pinCount: Int { get }
}

// MARK: - Backdrop (implemented in ShotBackdrop)

@MainActor
public protocol BackdropPresenting: AnyObject {
    /// Opens the backdrop composer (background, padding, radius, shadow, aspect presets).
    /// `onExport` receives the composed image.
    func openBackdrop(for capture: CaptureResult, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void)
}

// MARK: - History (implemented in ShotHistory)

public struct HistoryItem: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let fileURL: URL
    public let thumbnailURL: URL
    public let pixelSize: CGSize
    public let scale: CGFloat
    public let sourceAppName: String?
    public let kind: Kind
    /// OCR text, filled lazily for search.
    public let recognizedText: String?

    public enum Kind: String, Sendable, Codable {
        case image
        case video
        case gif
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        fileURL: URL,
        thumbnailURL: URL,
        pixelSize: CGSize,
        scale: CGFloat,
        sourceAppName: String?,
        kind: Kind,
        recognizedText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.pixelSize = pixelSize
        self.scale = scale
        self.sourceAppName = sourceAppName
        self.kind = kind
        self.recognizedText = recognizedText
    }
}

@MainActor
public protocol HistoryStoring: AnyObject {
    /// Persists a copy of the capture into the app's history store.
    @discardableResult
    func add(_ capture: CaptureResult) throws -> HistoryItem
    @discardableResult
    func addRecording(_ recording: RecordingResult) throws -> HistoryItem
    func recentItems(limit: Int) -> [HistoryItem]
    func loadCapture(_ item: HistoryItem) -> CaptureResult?
    func remove(_ item: HistoryItem) throws
    func removeAll() throws
}

@MainActor
public protocol HistoryPresenting: AnyObject {
    /// Opens the history browser window (grid, search, reopen in editor, copy, reveal, delete).
    func showHistory(onOpen: @escaping @MainActor (CaptureResult) -> Void)
}

// MARK: - Measurement (implemented in ShotMeasure)

@MainActor
public protocol Measuring: AnyObject {
    /// Interactive ruler over a frozen snapshot: edge-detected horizontal/vertical distances,
    /// drag to measure a box. Copies the last measurement as "W × H" on click. Esc exits.
    func startMeasuring() async throws
}
