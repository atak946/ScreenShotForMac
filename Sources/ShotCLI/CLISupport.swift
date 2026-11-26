import Foundation

enum CLIUsage {
    static let version = "1.0.0"

    static let text = """
    ssfm — control ScreenShotForMac from the command line

    USAGE
      ssfm <command> [options]

    COMMANDS
      capture [area|window|fullscreen|scrolling|last] [--copy|--save|--edit|--upload|--pin] [--delay N]
                         Take a screenshot. Without an action flag the app's
                         "after capture" setting is used. Delay: 0-30 seconds.
      record [mp4|gif]   Start (or stop) a screen recording. Default: mp4.
      ocr                Capture an area and copy its text.
      color              Pick a color from the screen and copy it.
      qr                 Scan a QR code or barcode on screen.
      measure            Open the pixel ruler.
      workflow <name|id> Run a saved workflow.
      history            Open the capture history.
      open <file>        Open an image file in the editor.
      settings           Open Settings.

    OPTIONS
      -h, --help         Show this help.
      -v, --version      Show the version.

    EXAMPLES
      ssfm capture --copy
      ssfm capture window --save --delay 3
      ssfm workflow "Capture → Upload → Copy link"
      ssfm open ~/Desktop/shot.png

    EXIT CODES
      0 success, 1 failure, 64 invalid usage, 69 app not available
    """
}

/// Opens the URL with `/usr/bin/open -g` so the app handles it in the background.
enum URLLauncher {
    static let openToolPath = "/usr/bin/open"

    static func open(_ url: URL) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: openToolPath)
        process.arguments = ["-g", url.absoluteString]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            FileHandle.standardError.write(Data("ssfm: could not run open: \(error.localizedDescription)\n".utf8))
            return CLIExit.failure
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            FileHandle.standardError.write(Data("ssfm: ScreenShotForMac is not installed or did not accept the request.\n\(details)".utf8))
            return CLIExit.appUnavailable
        }
        return CLIExit.success
    }
}
