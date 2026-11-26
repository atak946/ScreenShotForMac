import AppKit

/// Button that reacts to the very first click, even when its window is not key.
/// Required inside non-activating panels, where AppKit otherwise swallows the
/// first click as a window activation click.
final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
