import Foundation
import Observation

public enum ImageFormat: String, Sendable, CaseIterable, Codable, Identifiable {
    case png
    case jpeg
    case heic

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        }
    }
}

/// What happens right after a capture finishes.
public enum AfterCaptureBehavior: String, Sendable, CaseIterable, Codable, Identifiable {
    case showQuickAccess
    case openEditor
    case copyToClipboard
    case saveToFile

    public var id: String { rawValue }
}

public enum ColorFormat: String, Sendable, CaseIterable, Codable, Identifiable {
    case hex
    case rgb
    case hsl
    case swiftUI
    case nsColor

    public var id: String { rawValue }
}

/// UI language override. `system` follows the macOS preferred languages.
public enum AppLanguage: String, Sendable, CaseIterable, Codable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    public var id: String { rawValue }

    /// Name shown in its own language (intentionally not translated).
    public var nativeName: String {
        switch self {
        case .system: return String(localized: "System Default", bundle: .module)
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }
}

/// Single source of truth for user preferences, persisted in UserDefaults.
/// Read anywhere on the main actor; mutate only from the Settings UI.
@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    private let defaults: UserDefaults

    public var afterCapture: AfterCaptureBehavior {
        didSet { defaults.set(afterCapture.rawValue, forKey: Keys.afterCapture) }
    }

    public var alsoCopyToClipboard: Bool {
        didSet { defaults.set(alsoCopyToClipboard, forKey: Keys.alsoCopy) }
    }

    public var imageFormat: ImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Keys.imageFormat) }
    }

    /// 0...1, used for JPEG / HEIC.
    public var imageQuality: Double {
        didSet { defaults.set(imageQuality, forKey: Keys.imageQuality) }
    }

    /// Save at 1x on Retina displays.
    public var downscaleRetina: Bool {
        didSet { defaults.set(downscaleRetina, forKey: Keys.downscale) }
    }

    /// Tokens: {date} {time} {app} {counter} {timestamp}
    public var filenameTemplate: String {
        didSet { defaults.set(filenameTemplate, forKey: Keys.filenameTemplate) }
    }

    /// Security-scoped bookmark of the save folder; nil means ~/Desktop.
    public var saveFolderBookmark: Data? {
        didSet { defaults.set(saveFolderBookmark, forKey: Keys.saveFolder) }
    }

    public var captureWindowShadow: Bool {
        didSet { defaults.set(captureWindowShadow, forKey: Keys.windowShadow) }
    }

    public var showMagnifier: Bool {
        didSet { defaults.set(showMagnifier, forKey: Keys.magnifier) }
    }

    public var colorFormat: ColorFormat {
        didSet { defaults.set(colorFormat.rawValue, forKey: Keys.colorFormat) }
    }

    /// BCP-47 codes for OCR, e.g. ["en-US", "tr-TR"].
    public var ocrLanguages: [String] {
        didSet { defaults.set(ocrLanguages, forKey: Keys.ocrLanguages) }
    }

    public var quickAccessAutoCloseSeconds: Double {
        didSet { defaults.set(quickAccessAutoCloseSeconds, forKey: Keys.quickAccessTimeout) }
    }

    // MARK: Capture extras

    /// Seconds for `captureDelayed`.
    public var captureDelaySeconds: Int {
        didSet { defaults.set(captureDelaySeconds, forKey: Keys.captureDelay) }
    }

    // MARK: Recording

    public var recordSystemAudio: Bool {
        didSet { defaults.set(recordSystemAudio, forKey: Keys.recordSystemAudio) }
    }

    public var recordMicrophone: Bool {
        didSet { defaults.set(recordMicrophone, forKey: Keys.recordMicrophone) }
    }

    public var recordShowCursor: Bool {
        didSet { defaults.set(recordShowCursor, forKey: Keys.recordShowCursor) }
    }

    public var recordHighlightClicks: Bool {
        didSet { defaults.set(recordHighlightClicks, forKey: Keys.recordHighlightClicks) }
    }

    public var recordFramesPerSecond: Int {
        didSet { defaults.set(recordFramesPerSecond, forKey: Keys.recordFPS) }
    }

    public var gifFramesPerSecond: Int {
        didSet { defaults.set(gifFramesPerSecond, forKey: Keys.gifFPS) }
    }

    /// Opens finished MP4 recordings in the trim editor instead of revealing them in Finder.
    public var openTrimEditorAfterRecording: Bool {
        didSet { defaults.set(openTrimEditorAfterRecording, forKey: Keys.openTrimEditor) }
    }

    // MARK: History

    public var historyEnabled: Bool {
        didSet { defaults.set(historyEnabled, forKey: Keys.historyEnabled) }
    }

    /// 0 = keep forever.
    public var historyRetentionDays: Int {
        didSet { defaults.set(historyRetentionDays, forKey: Keys.historyRetention) }
    }

    // MARK: Editor

    public var editorCloseAfterSave: Bool {
        didSet { defaults.set(editorCloseAfterSave, forKey: Keys.editorCloseAfterSave) }
    }

    /// Applied on next launch via the `AppleLanguages` override.
    public var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            Self.applyLanguageOverride(appLanguage)
        }
    }

    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        afterCapture = defaults.string(forKey: Keys.afterCapture)
            .flatMap(AfterCaptureBehavior.init(rawValue:)) ?? .showQuickAccess
        alsoCopyToClipboard = defaults.object(forKey: Keys.alsoCopy) as? Bool ?? true
        imageFormat = defaults.string(forKey: Keys.imageFormat).flatMap(ImageFormat.init(rawValue:)) ?? .png
        imageQuality = defaults.object(forKey: Keys.imageQuality) as? Double ?? 0.9
        downscaleRetina = defaults.bool(forKey: Keys.downscale)
        filenameTemplate = defaults.string(forKey: Keys.filenameTemplate) ?? "Screenshot {date} at {time}"
        saveFolderBookmark = defaults.data(forKey: Keys.saveFolder)
        captureWindowShadow = defaults.object(forKey: Keys.windowShadow) as? Bool ?? true
        showMagnifier = defaults.object(forKey: Keys.magnifier) as? Bool ?? true
        colorFormat = defaults.string(forKey: Keys.colorFormat).flatMap(ColorFormat.init(rawValue:)) ?? .hex
        ocrLanguages = defaults.stringArray(forKey: Keys.ocrLanguages) ?? ["en-US", "tr-TR"]
        quickAccessAutoCloseSeconds = defaults.object(forKey: Keys.quickAccessTimeout) as? Double ?? 8
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        captureDelaySeconds = defaults.object(forKey: Keys.captureDelay) as? Int ?? 3
        recordSystemAudio = defaults.bool(forKey: Keys.recordSystemAudio)
        recordMicrophone = defaults.bool(forKey: Keys.recordMicrophone)
        recordShowCursor = defaults.object(forKey: Keys.recordShowCursor) as? Bool ?? true
        recordHighlightClicks = defaults.bool(forKey: Keys.recordHighlightClicks)
        recordFramesPerSecond = defaults.object(forKey: Keys.recordFPS) as? Int ?? 30
        gifFramesPerSecond = defaults.object(forKey: Keys.gifFPS) as? Int ?? 15
        openTrimEditorAfterRecording = defaults.bool(forKey: Keys.openTrimEditor)
        historyEnabled = defaults.object(forKey: Keys.historyEnabled) as? Bool ?? true
        historyRetentionDays = defaults.object(forKey: Keys.historyRetention) as? Int ?? 30
        editorCloseAfterSave = defaults.object(forKey: Keys.editorCloseAfterSave) as? Bool ?? true
        appLanguage = defaults.string(forKey: Keys.appLanguage).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    private static func applyLanguageOverride(_ language: AppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .turkish:
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    /// Recording options derived from current preferences.
    public func recordingOptions(format: RecordingFormat) -> RecordingOptions {
        RecordingOptions(
            format: format,
            captureSystemAudio: format == .mp4 && recordSystemAudio,
            captureMicrophone: format == .mp4 && recordMicrophone,
            showCursor: recordShowCursor,
            highlightClicks: recordHighlightClicks,
            framesPerSecond: format == .gif ? gifFramesPerSecond : recordFramesPerSecond
        )
    }

    private enum Keys {
        static let afterCapture = "afterCapture"
        static let alsoCopy = "alsoCopyToClipboard"
        static let imageFormat = "imageFormat"
        static let imageQuality = "imageQuality"
        static let downscale = "downscaleRetina"
        static let filenameTemplate = "filenameTemplate"
        static let saveFolder = "saveFolderBookmark"
        static let windowShadow = "captureWindowShadow"
        static let magnifier = "showMagnifier"
        static let colorFormat = "colorFormat"
        static let ocrLanguages = "ocrLanguages"
        static let quickAccessTimeout = "quickAccessAutoCloseSeconds"
        static let onboarding = "hasCompletedOnboarding"
        static let captureDelay = "captureDelaySeconds"
        static let recordSystemAudio = "recordSystemAudio"
        static let recordMicrophone = "recordMicrophone"
        static let recordShowCursor = "recordShowCursor"
        static let recordHighlightClicks = "recordHighlightClicks"
        static let recordFPS = "recordFramesPerSecond"
        static let gifFPS = "gifFramesPerSecond"
        static let openTrimEditor = "openTrimEditorAfterRecording"
        static let historyEnabled = "historyEnabled"
        static let historyRetention = "historyRetentionDays"
        static let editorCloseAfterSave = "editorCloseAfterSave"
        static let appLanguage = "appLanguage"
    }
}
