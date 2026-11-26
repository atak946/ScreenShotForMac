import AppKit
import Foundation

/// Opens trim-editor windows for recorded videos (MP4 / MOV; GIF sources are not supported).
///
/// The editor offers in / out trimming on a filmstrip, play / pause (Space), audio removal,
/// speed (0.5× – 2×) and MP4 or GIF output. Saving writes "<name> (edited).<ext>" next to
/// the source by default, or overwrites the source, then calls `onSaved` and closes.
@MainActor
public final class VideoEditorPresenter {
    private var controllers: [VideoEditorWindowController] = []

    public init() {}

    /// Opens (or brings to front) the editor for `url`.
    public func open(url: URL, onSaved: @escaping @MainActor (URL) -> Void) {
        let standardized = url.standardizedFileURL
        if let existing = controllers.first(where: { $0.sourceURL == standardized }) {
            existing.show()
            return
        }
        let controller = VideoEditorWindowController(
            url: standardized,
            onSaved: onSaved,
            onClose: { [weak self] closed in
                self?.controllers.removeAll { $0 === closed }
            }
        )
        controllers.append(controller)
        controller.show()
    }
}
