import AppKit
import CoreGraphics
import Foundation

// MARK: - Capture (implemented in ShotCapture)

@MainActor
public protocol CaptureServicing: AnyObject {
    /// Runs the interactive capture flow for the given mode.
    /// Returns `nil` when the user cancels (Esc / right click).
    func capture(_ mode: CaptureMode) async throws -> CaptureResult?

    /// Captures every display without UI (used to freeze the screen for overlays).
    /// One result per display, in `NSScreen.screens` order.
    func snapshotAllDisplays() async throws -> [CaptureResult]

    /// Whether Screen Recording permission is granted.
    func hasScreenRecordingPermission() -> Bool

    /// Triggers the system permission prompt.
    func requestScreenRecordingPermission()
}

// MARK: - Editor (implemented in ShotEditor)

@MainActor
public protocol EditorPresenting: AnyObject {
    /// Opens an editor window for the capture. `onExport` delivers the flattened image
    /// together with the action the user picked in the editor toolbar.
    func openEditor(for capture: CaptureResult, onExport: @escaping @MainActor (CGImage, ExportAction) -> Void)
}

// MARK: - Export (implemented in ShotExport)

public enum ExportAction: String, Sendable, CaseIterable, Codable {
    case copy
    case save
    case saveAs
}

@MainActor
public protocol ExportServicing: AnyObject {
    func copyToClipboard(_ image: CGImage, scale: CGFloat)
    func copyText(_ text: String)
    /// Saves into the configured folder using the filename template. Returns the file URL.
    @discardableResult
    func save(_ image: CGImage, scale: CGFloat, context: FilenameContext) throws -> URL
    /// Shows an NSSavePanel. Returns nil when cancelled.
    @discardableResult
    func saveAs(_ image: CGImage, scale: CGFloat, context: FilenameContext) throws -> URL?
}

public struct FilenameContext: Sendable {
    public let date: Date
    public let appName: String?
    public init(date: Date = Date(), appName: String? = nil) {
        self.date = date
        self.appName = appName
    }
}

/// Small floating preview shown after a capture (bottom corner of the screen).
@MainActor
public protocol QuickAccessPresenting: AnyObject {
    func show(_ capture: CaptureResult, handlers: QuickAccessHandlers)
    func dismissAll()
}

public struct QuickAccessHandlers {
    public let onEdit: @MainActor () -> Void
    public let onCopy: @MainActor () -> Void
    public let onSave: @MainActor () -> Void
    public let onPin: (@MainActor () -> Void)?
    /// Shows an Upload chip when non-nil.
    public let onUpload: (@MainActor () -> Void)?

    public init(
        onEdit: @escaping @MainActor () -> Void,
        onCopy: @escaping @MainActor () -> Void,
        onSave: @escaping @MainActor () -> Void,
        onPin: (@MainActor () -> Void)? = nil,
        onUpload: (@MainActor () -> Void)? = nil
    ) {
        self.onEdit = onEdit
        self.onCopy = onCopy
        self.onSave = onSave
        self.onPin = onPin
        self.onUpload = onUpload
    }
}

// MARK: - Tools (implemented in ShotTools)

@MainActor
public protocol TextRecognizing: AnyObject {
    /// Recognizes text in the image. Lines are joined with "\n".
    func recognizeText(in image: CGImage, languages: [String]) async throws -> String
    /// Returns decoded payloads of all QR / barcodes found.
    func detectCodes(in image: CGImage) async throws -> [String]
}

@MainActor
public protocol ColorPicking: AnyObject {
    /// Shows a full-screen magnifier picker over a frozen snapshot.
    /// Returns the picked color, or nil if cancelled.
    func pickColor() async throws -> PickedColor?
}

public struct PickedColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: - User feedback (implemented in App target)

@MainActor
public protocol UserNotifying: AnyObject {
    /// Short transient HUD message, e.g. "Copied to clipboard".
    func showHUD(_ message: String)
    func showError(_ error: Error)
}
