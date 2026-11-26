import Foundation

/// File type written by the trim editor.
enum VideoOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case mp4
    case gif

    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var title: String { rawValue.uppercased() }
}

/// Playback / export speed multiplier.
enum PlaybackSpeed: Double, CaseIterable, Identifiable, Sendable {
    case half = 0.5
    case normal = 1
    case oneAndHalf = 1.5
    case double = 2

    var id: Double { rawValue }
    var title: String { rawValue.formatted(.number.precision(.fractionLength(0...1))) + "×" }
}

/// Maximum GIF width in pixels; `original` keeps the video size.
enum GIFWidth: Int, CaseIterable, Identifiable, Sendable {
    case w480 = 480
    case w640 = 640
    case w800 = 800
    case w960 = 960
    case original = 0

    var id: Int { rawValue }
    var maxWidth: CGFloat? { self == .original ? nil : CGFloat(rawValue) }
    var title: String {
        self == .original ? String(localized: "Original", bundle: .module) : "\(rawValue) px"
    }
}

/// Where the edited file goes.
enum VideoSaveMode: String, CaseIterable, Identifiable, Sendable {
    case copy
    case overwrite

    var id: String { rawValue }
    var title: String {
        switch self {
        case .copy: return String(localized: "Save as Copy", bundle: .module)
        case .overwrite: return String(localized: "Overwrite Original", bundle: .module)
        }
    }
}

/// Everything an exporter needs, as plain Sendable values.
struct VideoExportRequest: Sendable {
    let sourceURL: URL
    let outputURL: URL
    /// Trim range on the source timeline, in seconds.
    let start: Double
    let end: Double
    let speed: Double
    let removesAudio: Bool
    let gifFramesPerSecond: Int
    let gifMaxWidth: CGFloat?
}

enum VideoEditorError: LocalizedError {
    case unreadable
    case exportUnavailable
    case exportFailed(String)
    case gifCreationFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return String(localized: "This video cannot be opened.", bundle: .module)
        case .exportUnavailable:
            return String(localized: "This video cannot be exported.", bundle: .module)
        case let .exportFailed(reason):
            return String(localized: "Export failed: \(reason)", bundle: .module)
        case .gifCreationFailed:
            return String(localized: "The GIF file could not be written.", bundle: .module)
        }
    }
}

enum VideoTimeFormat {
    /// `m:ss.t`, e.g. `1:05.3`.
    static func string(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let tenths = Int((clamped * 10).rounded(.down))
        let minutes = tenths / 600
        let secs = (tenths / 10) % 60
        return String(format: "%d:%02d.%d", minutes, secs, tenths % 10)
    }
}
