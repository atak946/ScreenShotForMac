import Foundation

/// Shape of the webcam bubble.
public enum WebcamShape: String, Sendable, CaseIterable, Identifiable {
    case circle
    case roundedRect

    public var id: String { rawValue }
}

/// Size preset of the webcam bubble.
public enum WebcamSize: String, Sendable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    /// Height of the bubble in points.
    var side: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 180
        case .large: return 260
        }
    }
}

/// Recording extras that live outside `AppSettings` (webcam, keystrokes).
/// Persisted in `UserDefaults` under module-local keys.
public struct RecordingExtrasPreferences: Sendable, Equatable {
    public var showWebcam: Bool
    public var webcamShape: WebcamShape
    public var webcamSize: WebcamSize
    public var showKeystrokes: Bool
    /// Only show combos with ⌘ / ⌃ / ⌥ and special keys, never plain typed text.
    public var keystrokesShortcutsOnly: Bool

    public init(
        showWebcam: Bool = false,
        webcamShape: WebcamShape = .circle,
        webcamSize: WebcamSize = .medium,
        showKeystrokes: Bool = false,
        keystrokesShortcutsOnly: Bool = true
    ) {
        self.showWebcam = showWebcam
        self.webcamShape = webcamShape
        self.webcamSize = webcamSize
        self.showKeystrokes = showKeystrokes
        self.keystrokesShortcutsOnly = keystrokesShortcutsOnly
    }

    public static func load(from defaults: UserDefaults = .standard) -> RecordingExtrasPreferences {
        let fallback = RecordingExtrasPreferences()
        return RecordingExtrasPreferences(
            showWebcam: defaults.object(forKey: Keys.showWebcam) as? Bool ?? fallback.showWebcam,
            webcamShape: defaults.string(forKey: Keys.webcamShape).flatMap(WebcamShape.init(rawValue:)) ?? fallback.webcamShape,
            webcamSize: defaults.string(forKey: Keys.webcamSize).flatMap(WebcamSize.init(rawValue:)) ?? fallback.webcamSize,
            showKeystrokes: defaults.object(forKey: Keys.showKeystrokes) as? Bool ?? fallback.showKeystrokes,
            keystrokesShortcutsOnly: defaults.object(forKey: Keys.shortcutsOnly) as? Bool ?? fallback.keystrokesShortcutsOnly
        )
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(showWebcam, forKey: Keys.showWebcam)
        defaults.set(webcamShape.rawValue, forKey: Keys.webcamShape)
        defaults.set(webcamSize.rawValue, forKey: Keys.webcamSize)
        defaults.set(showKeystrokes, forKey: Keys.showKeystrokes)
        defaults.set(keystrokesShortcutsOnly, forKey: Keys.shortcutsOnly)
    }

    private enum Keys {
        static let showWebcam = "recording.extras.showWebcam"
        static let webcamShape = "recording.extras.webcamShape"
        static let webcamSize = "recording.extras.webcamSize"
        static let showKeystrokes = "recording.extras.showKeystrokes"
        static let shortcutsOnly = "recording.extras.keystrokesShortcutsOnly"
    }
}
