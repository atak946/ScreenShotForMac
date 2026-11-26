import ShotCore

extension AfterCaptureBehavior {
    var label: String {
        switch self {
        case .showQuickAccess: return String(localized: "Show Quick Access overlay", bundle: .module)
        case .openEditor: return String(localized: "Open in editor", bundle: .module)
        case .copyToClipboard: return String(localized: "Copy to clipboard", bundle: .module)
        case .saveToFile: return String(localized: "Save to file", bundle: .module)
        }
    }
}

extension ImageFormat {
    var label: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        }
    }

    var supportsQuality: Bool { self != .png }
}

extension ColorFormat {
    var label: String {
        switch self {
        case .hex: return "HEX  (#1E90FF)"
        case .rgb: return "RGB  (rgb(30, 144, 255))"
        case .hsl: return "HSL  (hsl(210, 100%, 56%))"
        case .swiftUI: return "SwiftUI  (Color(red:green:blue:))"
        case .nsColor: return "NSColor  (NSColor(srgbRed:…))"
        }
    }
}
