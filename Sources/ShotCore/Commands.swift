import Foundation

/// Every user-triggerable command. Hotkeys, menu items and URL scheme map onto these.
public enum AppCommand: String, Sendable, CaseIterable, Codable, Identifiable {
    case captureArea
    case captureWindow
    case captureFullscreen
    case captureLastArea
    case captureDelayed
    case captureScrolling
    case recordVideo
    case recordGIF
    case recognizeText
    case pickColor
    case scanQRCode
    case measure
    case pinFromClipboard
    case openFromClipboard
    case showHistory
    case openSettings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .captureArea: return String(localized: "Capture Area", bundle: .module)
        case .captureWindow: return String(localized: "Capture Window", bundle: .module)
        case .captureFullscreen: return String(localized: "Capture Fullscreen", bundle: .module)
        case .captureLastArea: return String(localized: "Capture Previous Area", bundle: .module)
        case .captureDelayed: return String(localized: "Capture Area with Timer", bundle: .module)
        case .captureScrolling: return String(localized: "Scrolling Capture", bundle: .module)
        case .recordVideo: return String(localized: "Record Screen (Video)", bundle: .module)
        case .recordGIF: return String(localized: "Record Screen (GIF)", bundle: .module)
        case .recognizeText: return String(localized: "Capture Text (OCR)", bundle: .module)
        case .pickColor: return String(localized: "Pick Color", bundle: .module)
        case .scanQRCode: return String(localized: "Scan QR Code", bundle: .module)
        case .measure: return String(localized: "Measure (Pixel Ruler)", bundle: .module)
        case .pinFromClipboard: return String(localized: "Pin Image from Clipboard", bundle: .module)
        case .openFromClipboard: return String(localized: "Open Clipboard in Editor", bundle: .module)
        case .showHistory: return String(localized: "Capture History…", bundle: .module)
        case .openSettings: return String(localized: "Settings…", bundle: .module)
        }
    }

    public var systemImage: String {
        switch self {
        case .captureArea: return "crop"
        case .captureWindow: return "macwindow"
        case .captureFullscreen: return "display"
        case .captureLastArea: return "arrow.counterclockwise.square"
        case .captureDelayed: return "timer"
        case .captureScrolling: return "arrow.up.and.down.square"
        case .recordVideo: return "record.circle"
        case .recordGIF: return "photo.stack"
        case .recognizeText: return "text.viewfinder"
        case .pickColor: return "eyedropper"
        case .scanQRCode: return "qrcode.viewfinder"
        case .measure: return "ruler"
        case .pinFromClipboard: return "pin"
        case .openFromClipboard: return "doc.on.clipboard"
        case .showHistory: return "clock.arrow.circlepath"
        case .openSettings: return "gearshape"
        }
    }
}

/// Implemented by the App target; modules call it to trigger commands.
@MainActor
public protocol CommandHandling: AnyObject {
    func perform(_ command: AppCommand)
}
