import Foundation
import ShotCore

extension WorkflowStepKind {
    public var title: String {
        switch self {
        case .annotateInEditor: return String(localized: "Annotate in Editor", bundle: .module)
        case .autoRedactSensitive: return String(localized: "Redact Sensitive Data", bundle: .module)
        case .applyBackdropPreset: return String(localized: "Apply Backdrop Preset", bundle: .module)
        case .downscaleTo1x: return String(localized: "Downscale to 1x", bundle: .module)
        case .copyImage: return String(localized: "Copy Image", bundle: .module)
        case .saveToFolder: return String(localized: "Save to Folder", bundle: .module)
        case .upload: return String(localized: "Upload", bundle: .module)
        case .copyUploadLink: return String(localized: "Copy Upload Link", bundle: .module)
        case .ocrCopyText: return String(localized: "Copy Recognized Text", bundle: .module)
        case .pin: return String(localized: "Pin to Screen", bundle: .module)
        case .showQuickAccess: return String(localized: "Show Quick Access", bundle: .module)
        case .openWith: return String(localized: "Open With App", bundle: .module)
        case .runShortcut: return String(localized: "Run Shortcut", bundle: .module)
        case .playSound: return String(localized: "Play Sound", bundle: .module)
        }
    }

    public var systemImage: String {
        switch self {
        case .annotateInEditor: return "pencil.tip.crop.circle"
        case .autoRedactSensitive: return "eye.slash"
        case .applyBackdropPreset: return "rectangle.inset.filled"
        case .downscaleTo1x: return "arrow.down.right.and.arrow.up.left"
        case .copyImage: return "doc.on.doc"
        case .saveToFolder: return "folder"
        case .upload: return "icloud.and.arrow.up"
        case .copyUploadLink: return "link"
        case .ocrCopyText: return "text.viewfinder"
        case .pin: return "pin"
        case .showQuickAccess: return "rectangle.bottomhalf.inset.filled"
        case .openWith: return "arrow.up.forward.app"
        case .runShortcut: return "square.stack.3d.up"
        case .playSound: return "speaker.wave.2"
        }
    }

    /// Menu grouping for "Add Step".
    public var group: WorkflowStepGroup {
        switch self {
        case .annotateInEditor, .autoRedactSensitive, .applyBackdropPreset, .downscaleTo1x: return .edit
        case .copyImage, .saveToFolder, .upload, .copyUploadLink, .ocrCopyText: return .output
        case .pin, .showQuickAccess, .openWith, .runShortcut, .playSound: return .other
        }
    }
}

public enum WorkflowStepGroup: String, CaseIterable, Identifiable, Sendable {
    case edit
    case output
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .edit: return String(localized: "Edit", bundle: .module)
        case .output: return String(localized: "Output", bundle: .module)
        case .other: return String(localized: "More", bundle: .module)
        }
    }

    public var kinds: [WorkflowStepKind] {
        WorkflowStepKind.allCases.filter { $0.group == self }
    }
}

extension WorkflowStep {
    public var title: String { kind.title }
    public var systemImage: String { kind.systemImage }

    /// Short description of the configured parameter, if any.
    public var detail: String? {
        switch self {
        case let .applyBackdropPreset(name):
            return name.isEmpty ? String(localized: "Last used style", bundle: .module) : name
        case let .saveToFolder(bookmark):
            guard let bookmark, let url = FolderBookmark.resolve(bookmark) else {
                return String(localized: "Default save folder", bundle: .module)
            }
            return url.lastPathComponent
        case let .openWith(bundleID):
            return bundleID.isEmpty ? nil : bundleID
        case let .runShortcut(name):
            return name.isEmpty ? nil : name
        default:
            return nil
        }
    }
}

extension CaptureMode {
    public var workflowTitle: String {
        switch self {
        case .area: return String(localized: "Area", bundle: .module)
        case .window: return String(localized: "Window", bundle: .module)
        case .fullscreen: return String(localized: "Fullscreen", bundle: .module)
        }
    }

    public var workflowSymbol: String {
        switch self {
        case .area: return "crop"
        case .window: return "macwindow"
        case .fullscreen: return "display"
        }
    }
}
