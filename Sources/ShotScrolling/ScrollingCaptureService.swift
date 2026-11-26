import AppKit
import CoreGraphics
import ShotCore

/// Scrolling capture: the user selects an area on the live screen, then scrolls (manually or with
/// auto-scroll) while frames are captured with ScreenCaptureKit and stitched into one tall image.
@MainActor
public final class ScrollingCaptureService: ScrollingCapturing {
    private let settings: AppSettings
    private var isSessionActive = false

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public func captureScrolling() async throws -> CaptureResult? {
        guard !isSessionActive else {
            Log.capture.info("Ignoring scrolling capture: a session is already active")
            return nil
        }
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        isSessionActive = true
        defer { isSessionActive = false }

        let sourceApp = frontmostAppName()
        Log.capture.info("Starting scrolling capture")
        guard let selection = await ScrollAreaSelector().run() else {
            Log.capture.info("Scrolling capture cancelled during selection")
            return nil
        }
        guard let stitched = try await ScrollSessionController(selection: selection).run() else {
            return nil
        }
        let image = stitched.cgImage
        Log.capture.info("Scrolling capture finished: \(image.width) x \(image.height) px")
        return CaptureResult(
            image: image,
            scale: selection.screen.backingScaleFactor,
            screenRect: selection.rect,
            mode: .area,
            sourceAppName: sourceApp
        )
    }

    /// Name of the frontmost app, ignoring this app itself.
    private func frontmostAppName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else { return nil }
        return app.localizedName
    }
}
