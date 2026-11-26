import AppKit
import CoreGraphics
import os
import ShotCore

extension Log {
    /// Logger for the screen recording module.
    static let recording = Logger(subsystem: Log.subsystem, category: "recording")
}

/// Small geometry and formatting helpers shared by the recording module.
enum RecordingGeometry {
    /// Height of the primary (menu bar) display, the pivot for the global y flip.
    @MainActor static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Converts a rect in CG global coordinates (top-left origin) to AppKit global coordinates.
    static func appKitRect(fromQuartz rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Largest even integer not above `value` (video encoders need even dimensions), minimum 2.
    static func even(_ value: CGFloat) -> Int {
        max(2, Int(value.rounded(.down)) & ~1)
    }

    /// Formats seconds as `m:ss` or `h:mm:ss`.
    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

extension NSScreen {
    /// The CoreGraphics display ID backing this screen.
    var recordingDisplayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    /// The screen currently under the mouse cursor.
    @MainActor static var underCursor: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}

extension CGRect {
    /// Standardized rect spanning two points.
    init(spanning a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// NSObject target that forwards an AppKit action to a closure.
@MainActor
final class ClosureActionTarget: NSObject {
    private let handler: @MainActor () -> Void

    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @objc
    func perform(_ sender: Any?) {
        handler()
    }
}

/// Builds output file URLs inside the temporary recordings folder.
enum RecordingFileLocation {
    static func makeURL(format: RecordingFormat, date: Date = Date()) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenShotForMac", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let baseName = "Recording \(formatter.string(from: date))"
        let ext = format == .gif ? "gif" : "mp4"

        var candidate = folder.appendingPathComponent("\(baseName).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) (\(counter)).\(ext)")
            counter += 1
        }
        return candidate
    }
}
