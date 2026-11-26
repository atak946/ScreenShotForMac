import Foundation
import ShotCore

/// Example workflows created on first launch. Ids are fixed so "Restore Examples" can detect them.
public enum BuiltInWorkflows {
    public static var all: [Workflow] { [uploadAndCopyLink, redactAndCopy, windowBackdropSave] }

    public static var uploadAndCopyLink: Workflow {
        Workflow(
            id: fixedID("6F1C2B9E-2D3A-4C11-9A7B-0E5D1F2A3B01"),
            name: String(localized: "Capture → Upload → Copy link", bundle: .module),
            symbol: "icloud.and.arrow.up",
            captureMode: .area,
            steps: [.upload, .copyUploadLink, .playSound]
        )
    }

    public static var redactAndCopy: Workflow {
        Workflow(
            id: fixedID("6F1C2B9E-2D3A-4C11-9A7B-0E5D1F2A3B02"),
            name: String(localized: "Capture → Redact → Copy", bundle: .module),
            symbol: "eye.slash",
            captureMode: .area,
            steps: [.autoRedactSensitive, .copyImage, .showQuickAccess]
        )
    }

    public static var windowBackdropSave: Workflow {
        Workflow(
            id: fixedID("6F1C2B9E-2D3A-4C11-9A7B-0E5D1F2A3B03"),
            name: String(localized: "Window → Backdrop → Save", bundle: .module),
            symbol: "macwindow",
            captureMode: .window,
            steps: [.applyBackdropPreset(name: ""), .saveToFolder(bookmark: nil), .showQuickAccess]
        )
    }

    private static func fixedID(_ string: String) -> UUID {
        UUID(uuidString: string) ?? UUID()
    }
}
