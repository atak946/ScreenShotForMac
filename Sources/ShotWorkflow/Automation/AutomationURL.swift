import Foundation
import ShotCore

/// What a capture should do afterwards when started from automation.
public enum AutomationAction: String, Sendable, CaseIterable, Codable {
    case copy
    case save
    case edit
    case upload
    case pin
}

/// A parsed `ssfm://` request.
public enum AutomationRequest: Sendable, Equatable {
    /// `action == nil` → follow the user's "after capture" setting.
    case capture(mode: CaptureMode, action: AutomationAction?, delay: Int)
    case scrollingCapture
    case record(RecordingFormat)
    case runWorkflow(WorkflowReference)
    case openFile(URL)
    /// Opens an image file in the Backdrop composer.
    case backdropFile(URL)
    /// Opens image files in the Combine window (in the given order).
    case combineFiles([URL])
    /// Plain app commands (`ocr`, `color`, `qr`, `settings`, `history`, …).
    case command(AppCommand)
}

public enum WorkflowReference: Sendable, Equatable {
    case id(UUID)
    case name(String)
}

/// Parses `ssfm://` URLs (Raycast, Alfred, Shortcuts, the `ssfm` CLI).
///
/// Routes:
/// - `ssfm://capture?mode=area|window|fullscreen|scrolling|last&action=copy|save|edit|upload|pin&delay=N`
/// - `ssfm://record?format=mp4|gif`
/// - `ssfm://workflow?id=<uuid>` or `ssfm://workflow?name=<name>`
/// - `ssfm://open?path=<file>`
/// - `ssfm://backdrop?path=<file>`
/// - `ssfm://combine?path=<a>&path=<b>…`
/// - `ssfm://ocr`, `ssfm://color`, `ssfm://qr`, `ssfm://measure`, `ssfm://history`, `ssfm://settings`
public enum AutomationURL {
    public static let scheme = "ssfm"
    public static let maxDelaySeconds = Workflow.maxDelaySeconds

    public static func parse(_ url: URL) -> AutomationRequest? {
        guard url.scheme?.lowercased() == scheme, let host = url.host()?.lowercased() else { return nil }
        let query = queryItems(of: url)
        switch host {
        case "capture": return captureRequest(query)
        case "record": return recordRequest(query)
        case "workflow": return workflowRequest(query)
        case "open": return openRequest(query)
        case "backdrop": return fileURL(query["path"]).map(AutomationRequest.backdropFile)
        case "combine": return combineRequest(url)
        default: return simpleCommand(host).map(AutomationRequest.command)
        }
    }

    // MARK: - Builders (used by intents and menus)

    public static func captureURL(mode: CaptureMode, action: AutomationAction?, delay: Int = 0) -> URL? {
        var items = [URLQueryItem(name: "mode", value: mode.rawValue)]
        if let action { items.append(URLQueryItem(name: "action", value: action.rawValue)) }
        if delay > 0 { items.append(URLQueryItem(name: "delay", value: String(delay))) }
        return build("capture", items)
    }

    public static func scrollingCaptureURL() -> URL? {
        build("capture", [URLQueryItem(name: "mode", value: "scrolling")])
    }

    public static func workflowURL(_ reference: WorkflowReference) -> URL? {
        switch reference {
        case let .id(id): return build("workflow", [URLQueryItem(name: "id", value: id.uuidString)])
        case let .name(name): return build("workflow", [URLQueryItem(name: "name", value: name)])
        }
    }

    public static func commandURL(_ host: String) -> URL? {
        build(host, [])
    }

    // MARK: - Routes

    private static func captureRequest(_ query: [String: String]) -> AutomationRequest? {
        let modeValue = query["mode"]?.lowercased() ?? CaptureMode.area.rawValue
        switch modeValue {
        case "scrolling": return .scrollingCapture
        case "last", "previous": return .command(.captureLastArea)
        default: break
        }
        guard let mode = CaptureMode(rawValue: modeValue) else { return nil }
        let action = query["action"].flatMap { AutomationAction(rawValue: $0.lowercased()) }
        if query["action"] != nil, action == nil { return nil }
        let delay = query["delay"].flatMap(Int.init) ?? 0
        return .capture(mode: mode, action: action, delay: min(max(delay, 0), maxDelaySeconds))
    }

    private static func recordRequest(_ query: [String: String]) -> AutomationRequest? {
        let value = query["format"]?.lowercased() ?? RecordingFormat.mp4.rawValue
        return RecordingFormat(rawValue: value).map(AutomationRequest.record)
    }

    private static func workflowRequest(_ query: [String: String]) -> AutomationRequest? {
        if let idValue = query["id"] {
            return UUID(uuidString: idValue).map { .runWorkflow(.id($0)) }
        }
        guard let name = query["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return .runWorkflow(.name(name))
    }

    private static func openRequest(_ query: [String: String]) -> AutomationRequest? {
        fileURL(query["path"]).map(AutomationRequest.openFile)
    }

    /// Every `path` item is a file; all must be valid absolute (or `~`) paths.
    private static func combineRequest(_ url: URL) -> AutomationRequest? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let paths = items.filter { $0.name.lowercased() == "path" }.map(\.value)
        guard !paths.isEmpty else { return nil }
        let urls = paths.compactMap(fileURL)
        guard urls.count == paths.count else { return nil }
        return .combineFiles(urls)
    }

    /// Absolute (or `~`-relative) file path → standardized file URL.
    private static func fileURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    private static func simpleCommand(_ host: String) -> AppCommand? {
        switch host {
        case "ocr": return .recognizeText
        case "color": return .pickColor
        case "qr": return .scanQRCode
        case "measure": return .measure
        case "history": return .showHistory
        case "settings": return .openSettings
        default: return nil
        }
    }

    // MARK: - Helpers

    private static func queryItems(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.reduce(into: [:]) { result, item in
            guard let value = item.value, result[item.name.lowercased()] == nil else { return }
            result[item.name.lowercased()] = value
        }
    }

    private static func build(_ host: String, _ items: [URLQueryItem]) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }
}
