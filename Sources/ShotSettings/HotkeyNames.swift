import AppKit
import KeyboardShortcuts
import ShotCore

extension KeyboardShortcuts.Name {
    private static let hyper: NSEvent.ModifierFlags = [.option, .shift]

    static let captureArea = Self("captureArea", default: .init(.one, modifiers: hyper))
    static let captureWindow = Self("captureWindow", default: .init(.two, modifiers: hyper))
    static let captureFullscreen = Self("captureFullscreen", default: .init(.three, modifiers: hyper))
    static let recognizeText = Self("recognizeText", default: .init(.four, modifiers: hyper))
    static let pickColor = Self("pickColor", default: .init(.five, modifiers: hyper))
    static let scanQRCode = Self("scanQRCode", default: .init(.six, modifiers: hyper))
    static let recordVideo = Self("recordVideo", default: .init(.seven, modifiers: hyper))
    static let recordGIF = Self("recordGIF", default: .init(.eight, modifiers: hyper))
    static let captureScrolling = Self("captureScrolling", default: .init(.nine, modifiers: hyper))
    static let measure = Self("measure", default: .init(.zero, modifiers: hyper))
    static let captureLastArea = Self("captureLastArea", default: .init(.r, modifiers: hyper))
    static let openFromClipboard = Self("openFromClipboard", default: .init(.v, modifiers: hyper))
    // Recordable, no default.
    static let captureDelayed = Self("captureDelayed")
    static let pinFromClipboard = Self("pinFromClipboard")
    static let showHistory = Self("showHistory")
}

/// Display groups for the Shortcuts settings tab.
public enum HotkeyGroup: String, CaseIterable, Identifiable, Sendable {
    case capture = "Capture"
    case recording = "Recording"
    case tools = "Tools"
    case app = "App"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .capture: return String(localized: "Capture", bundle: .module)
        case .recording: return String(localized: "Recording", bundle: .module)
        case .tools: return String(localized: "Tools", bundle: .module)
        case .app: return String(localized: "App", bundle: .module)
        }
    }

    public var commands: [AppCommand] {
        HotkeyRegistry.hotkeyCommands.filter { HotkeyRegistry.group(for: $0) == self }
    }
}

/// Maps app commands to their global hotkey names.
public enum HotkeyRegistry {
    /// Commands that can be bound to a global hotkey, in display order.
    public static let hotkeyCommands: [AppCommand] = AppCommand.allCases.filter { name(for: $0) != nil }

    /// The shortcut name for a command, or nil when the command has no global hotkey.
    public static func name(for command: AppCommand) -> KeyboardShortcuts.Name? {
        switch command {
        case .captureArea: return .captureArea
        case .captureWindow: return .captureWindow
        case .captureFullscreen: return .captureFullscreen
        case .captureLastArea: return .captureLastArea
        case .captureDelayed: return .captureDelayed
        case .captureScrolling: return .captureScrolling
        case .recordVideo: return .recordVideo
        case .recordGIF: return .recordGIF
        case .recognizeText: return .recognizeText
        case .pickColor: return .pickColor
        case .scanQRCode: return .scanQRCode
        case .measure: return .measure
        case .pinFromClipboard: return .pinFromClipboard
        case .openFromClipboard: return .openFromClipboard
        case .showHistory: return .showHistory
        case .openSettings: return nil
        }
    }

    public static func group(for command: AppCommand) -> HotkeyGroup {
        switch command {
        case .captureArea, .captureWindow, .captureFullscreen,
             .captureLastArea, .captureDelayed, .captureScrolling:
            return .capture
        case .recordVideo, .recordGIF:
            return .recording
        case .recognizeText, .pickColor, .scanQRCode, .measure:
            return .tools
        case .pinFromClipboard, .openFromClipboard, .showHistory, .openSettings:
            return .app
        }
    }

    /// All registered hotkey names.
    public static var allNames: [KeyboardShortcuts.Name] {
        hotkeyCommands.compactMap(name(for:))
    }
}
