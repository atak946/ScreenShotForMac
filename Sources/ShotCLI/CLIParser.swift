import Foundation

enum CLIExit {
    static let success: Int32 = 0
    static let failure: Int32 = 1
    static let usage: Int32 = 64
    static let appUnavailable: Int32 = 69
}

enum CLIOutcome: Equatable {
    case help
    case version
    case url(URL)
    case failure(String)
}

/// Turns command line arguments into an `ssfm://` URL.
enum CLIParser {
    static let scheme = "ssfm"
    static let maxDelay = 30
    static let captureModes = ["area", "window", "fullscreen", "scrolling", "last"]
    static let captureActions = ["copy", "save", "edit", "upload", "pin"]
    static let recordFormats = ["mp4", "gif"]

    static func parse(_ arguments: [String]) -> CLIOutcome {
        guard let command = arguments.first else { return .help }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "-h", "--help", "help": return .help
        case "-v", "--version", "version": return .version
        case "capture": return parseCapture(rest)
        case "record": return parseRecord(rest)
        case "workflow", "run": return parseWorkflow(rest)
        case "open": return parseOpen(rest)
        case "ocr", "color", "qr", "measure", "history", "settings":
            return rest.isEmpty ? build(command) : .failure("'\(command)' takes no arguments")
        default:
            return .failure("unknown command '\(command)'")
        }
    }

    // MARK: - Subcommands

    static func parseCapture(_ arguments: [String]) -> CLIOutcome {
        var mode = "area"
        var action: String?
        var delay = 0
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if captureModes.contains(argument) {
                mode = argument
            } else if argument.hasPrefix("--"), captureActions.contains(String(argument.dropFirst(2))) {
                guard action == nil else { return .failure("choose only one of --copy, --save, --edit, --upload, --pin") }
                action = String(argument.dropFirst(2))
            } else if argument == "--delay" || argument == "-d" {
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), (0...maxDelay).contains(value) else {
                    return .failure("--delay needs a number of seconds between 0 and \(maxDelay)")
                }
                delay = value
            } else {
                return .failure("unexpected argument '\(argument)' for capture")
            }
            index += 1
        }
        var items = [URLQueryItem(name: "mode", value: mode)]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        if delay > 0 { items.append(URLQueryItem(name: "delay", value: String(delay))) }
        return build("capture", items)
    }

    static func parseRecord(_ arguments: [String]) -> CLIOutcome {
        guard arguments.count <= 1 else { return .failure("record takes at most one format") }
        let format = arguments.first.map { $0.hasPrefix("--") ? String($0.dropFirst(2)) : $0 } ?? "mp4"
        guard recordFormats.contains(format) else { return .failure("unknown recording format '\(format)' (use mp4 or gif)") }
        return build("record", [URLQueryItem(name: "format", value: format)])
    }

    static func parseWorkflow(_ arguments: [String]) -> CLIOutcome {
        let reference = arguments.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !reference.isEmpty else { return .failure("workflow needs a name or id") }
        if UUID(uuidString: reference) != nil {
            return build("workflow", [URLQueryItem(name: "id", value: reference)])
        }
        return build("workflow", [URLQueryItem(name: "name", value: reference)])
    }

    static func parseOpen(_ arguments: [String]) -> CLIOutcome {
        guard arguments.count == 1, let path = arguments.first else { return .failure("open needs exactly one file path") }
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let absolute = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolute, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return .failure("no such file: \(path)")
        }
        return build("open", [URLQueryItem(name: "path", value: absolute)])
    }

    // MARK: - URL

    static func build(_ host: String, _ items: [URLQueryItem] = []) -> CLIOutcome {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = items.isEmpty ? nil : items
        guard let url = components.url else { return .failure("could not build URL") }
        return .url(url)
    }
}
