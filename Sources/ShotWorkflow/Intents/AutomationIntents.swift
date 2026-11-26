import AppIntents
import AppKit
import Foundation
import ShotCore

// Intents perform by opening the app's own `ssfm://` URL, so they stay decoupled
// from the capture / editor modules: the App's URL handler does the real work.
//
// Intent titles use literal `LocalizedStringResource`s (required for App Intents
// metadata extraction); they resolve against the App bundle's string catalog.

public enum CaptureModeOption: String, AppEnum {
    case area
    case window
    case fullscreen
    case scrolling

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Capture Mode"
    public static let caseDisplayRepresentations: [CaptureModeOption: DisplayRepresentation] = [
        .area: DisplayRepresentation(title: "Area", image: .init(systemName: "crop")),
        .window: DisplayRepresentation(title: "Window", image: .init(systemName: "macwindow")),
        .fullscreen: DisplayRepresentation(title: "Fullscreen", image: .init(systemName: "display")),
        .scrolling: DisplayRepresentation(title: "Scrolling", image: .init(systemName: "arrow.up.and.down.square")),
    ]
}

public enum CaptureActionOption: String, AppEnum {
    case automatic
    case copy
    case save
    case edit
    case upload
    case pin

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "After Capture"
    public static let caseDisplayRepresentations: [CaptureActionOption: DisplayRepresentation] = [
        .automatic: "Use App Setting",
        .copy: "Copy to Clipboard",
        .save: "Save to File",
        .edit: "Open in Editor",
        .upload: "Upload",
        .pin: "Pin to Screen",
    ]

    var automationAction: AutomationAction? {
        AutomationAction(rawValue: rawValue)
    }
}

public struct CaptureIntent: AppIntent {
    public static let title: LocalizedStringResource = "Take Screenshot"
    public static let description = IntentDescription("Captures an area, a window or the whole screen.")

    @Parameter(title: "Mode", default: .area) public var mode: CaptureModeOption

    @Parameter(title: "After Capture", default: .automatic) public var action: CaptureActionOption

    @Parameter(title: "Delay (seconds)", default: 0, inclusiveRange: (0, 30)) public var delay: Int

    public static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$mode) then \(\.$action)") {
            \.$delay
        }
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let url: URL?
        if mode == .scrolling {
            url = AutomationURL.scrollingCaptureURL()
        } else {
            let captureMode = CaptureMode(rawValue: mode.rawValue) ?? .area
            url = AutomationURL.captureURL(mode: captureMode, action: action.automationAction, delay: delay)
        }
        try IntentURLOpener.open(url)
        return .result()
    }
}

public struct RunWorkflowIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Workflow"
    public static let description = IntentDescription("Runs one of your capture workflows.")

    @Parameter(title: "Workflow") public var workflow: WorkflowEntity

    public static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$workflow)")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try IntentURLOpener.open(AutomationURL.workflowURL(.id(workflow.id)))
        return .result()
    }
}

/// Lets the user capture an area and returns the recognized text.
///
/// The app performs OCR through `ssfm://ocr`, which copies the text to the clipboard;
/// the intent waits for that clipboard change and returns its string. Returns an
/// empty string when the user cancels or nothing is found within the timeout.
public struct RecognizeTextIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture Text"
    public static let description = IntentDescription("Select an area of the screen and get its text.")

    static let timeout: Duration = .seconds(90)
    static let pollInterval: Duration = .milliseconds(250)

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let pasteboard = NSPasteboard.general
        let startCount = pasteboard.changeCount
        try IntentURLOpener.open(AutomationURL.commandURL("ocr"))
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.timeout)
        while clock.now < deadline {
            try await Task.sleep(for: Self.pollInterval)
            if pasteboard.changeCount != startCount {
                return .result(value: pasteboard.string(forType: .string) ?? "")
            }
        }
        return .result(value: "")
    }
}

enum IntentURLOpener {
    struct InvalidURL: LocalizedError {
        var errorDescription: String? { "Could not build the automation URL." }
    }

    @MainActor
    static func open(_ url: URL?) throws {
        guard let url else { throw InvalidURL() }
        NSWorkspace.shared.open(url)
    }
}
