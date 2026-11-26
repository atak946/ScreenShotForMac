import os

/// Shared loggers. Use `Log.capture.error("...")` instead of print().
public enum Log {
    public static let subsystem = "app.screenshotformac"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let editor = Logger(subsystem: subsystem, category: "editor")
    public static let tools = Logger(subsystem: subsystem, category: "tools")
    public static let export = Logger(subsystem: subsystem, category: "export")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
