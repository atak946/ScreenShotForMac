import AppKit

enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case select, arrow, line, rectangle, ellipse, text, highlight, blur, pixelate, spotlight, magnifier, fill, counter, pen, crop

    var id: String { rawValue }

    var shortcut: Character {
        switch self {
        case .select: return "v"
        case .arrow: return "a"
        case .line: return "l"
        case .rectangle: return "r"
        case .ellipse: return "o"
        case .text: return "t"
        case .highlight: return "h"
        case .blur: return "b"
        case .pixelate: return "p"
        case .spotlight: return "s"
        case .magnifier: return "m"
        case .fill: return "e"
        case .counter: return "n"
        case .pen: return "d"
        case .crop: return "c"
        }
    }

    var title: String {
        switch self {
        case .select: return String(localized: "Select", bundle: .module)
        case .arrow: return String(localized: "Arrow", bundle: .module)
        case .line: return String(localized: "Line", bundle: .module)
        case .rectangle: return String(localized: "Rectangle", bundle: .module)
        case .ellipse: return String(localized: "Ellipse", bundle: .module)
        case .text: return String(localized: "Text", bundle: .module)
        case .highlight: return String(localized: "Highlight", bundle: .module)
        case .blur: return String(localized: "Blur", bundle: .module)
        case .pixelate: return String(localized: "Pixelate", bundle: .module)
        case .spotlight: return String(localized: "Spotlight", bundle: .module)
        case .magnifier: return String(localized: "Magnifier", bundle: .module)
        case .fill: return String(localized: "Smart Erase", bundle: .module)
        case .counter: return String(localized: "Counter", bundle: .module)
        case .pen: return String(localized: "Pen", bundle: .module)
        case .crop: return String(localized: "Crop", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .blur: return "drop"
        case .pixelate: return "square.grid.3x3"
        case .spotlight: return "flashlight.on.fill"
        case .magnifier: return "plus.magnifyingglass"
        case .fill: return "eraser"
        case .counter: return "1.circle"
        case .pen: return "scribble"
        case .crop: return "crop"
        }
    }

    /// Name plus shortcut, e.g. "Arrow  A".
    var tooltip: String { "\(title)  \(String(shortcut).uppercased())" }

    /// The annotation kind this tool creates, if any.
    var annotationKind: AnnotationKind? {
        switch self {
        case .select, .crop: return nil
        case .arrow: return .arrow
        case .line: return .line
        case .rectangle: return .rectangle
        case .ellipse: return .ellipse
        case .text: return .text
        case .highlight: return .highlight
        case .blur: return .blur
        case .pixelate: return .pixelate
        case .spotlight: return .spotlight
        case .magnifier: return .magnifier
        case .fill: return .fill
        case .counter: return .counter
        case .pen: return .pen
        }
    }

    var usesColor: Bool {
        switch self {
        case .blur, .pixelate, .spotlight, .fill, .crop: return false
        default: return true
        }
    }

    var usesFill: Bool { self == .rectangle || self == .ellipse || self == .text }

    var usesFontSize: Bool { self == .text || self == .counter }

    var usesLineStyle: Bool { self == .arrow || self == .line || self == .rectangle || self == .ellipse || self == .pen }

    var usesCornerRadius: Bool { self == .rectangle || self == .spotlight }

    init?(kind: AnnotationKind) {
        guard let tool = EditorTool.allCases.first(where: { $0.annotationKind == kind }) else { return nil }
        self = tool
    }

    var cursor: NSCursor {
        switch self {
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    init?(shortcut: Character) {
        guard let tool = EditorTool.allCases.first(where: { $0.shortcut == shortcut }) else { return nil }
        self = tool
    }
}
