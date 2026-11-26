import AppKit
import CoreGraphics
import ShotCore

/// ScreenCaptureKit based implementation of `CaptureServicing`.
///
/// Area captures freeze every display first and let the user select on top of the
/// frozen pixels; window captures grab the picked window independently of what
/// covers it; fullscreen captures the display under the mouse cursor.
/// See `CaptureService+Extras.swift` for "last area" and delayed captures.
@MainActor
public final class CaptureService: CaptureServicing {
    let settings: AppSettings
    let snapshotter = ScreenSnapshotter()
    let lastAreaStore = LastAreaStore()
    private var isSessionActive = false

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    // MARK: - CaptureServicing

    public func capture(_ mode: CaptureMode) async throws -> CaptureResult? {
        try await runSession(mode.rawValue) {
            let sourceApp = self.frontmostAppName()
            switch mode {
            case .area:
                return try await self.interactiveArea(sourceApp: sourceApp)
            case .window:
                return try await self.interactiveWindow()
            case .fullscreen:
                return try await self.fullscreen(of: self.screenUnderCursor(), sourceApp: sourceApp)
            }
        }
    }

    public func snapshotAllDisplays() async throws -> [CaptureResult] {
        guard hasScreenRecordingPermission() else { throw CaptureError.permissionDenied }
        let sourceApp = frontmostAppName()
        let snapshots = try await takeSnapshots(of: NSScreen.screens)
        return snapshots.map { makeResult(from: $0, sourceApp: sourceApp) }
    }

    public func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public func requestScreenRecordingPermission() {
        let granted = CGRequestScreenCaptureAccess()
        Log.capture.info("Screen Recording permission requested, granted: \(granted, privacy: .public)")
    }

    // MARK: - Session

    /// Runs `body` as the single active capture session. Returns nil if one is already running.
    func runSession(
        _ name: String,
        _ body: () async throws -> CaptureResult?
    ) async throws -> CaptureResult? {
        guard !isSessionActive else {
            Log.capture.info("Ignoring \(name, privacy: .public) capture: a session is already active")
            return nil
        }
        guard hasScreenRecordingPermission() else { throw CaptureError.permissionDenied }
        isSessionActive = true
        defer { isSessionActive = false }
        Log.capture.info("Starting \(name, privacy: .public) capture")
        return try await body()
    }

    // MARK: - Interactive flows

    func interactiveArea(sourceApp: String?) async throws -> CaptureResult? {
        async let windowList = snapshotter.listWindows()
        let snapshots = try await takeSnapshots(of: NSScreen.screens)
        let windows = await LocatedWindow.locate((try? windowList) ?? [])

        let controller = AreaSelectionController(
            surfaces: snapshots.map(SelectionSurface.init(snapshot:)),
            windows: windows,
            showMagnifier: settings.showMagnifier
        )
        guard let selection = await controller.run() else {
            Log.capture.info("Area capture cancelled")
            return nil
        }
        guard let snapshot = selection.surface.snapshot else {
            throw CaptureError.captureFailed(String(localized: "The frozen snapshot is missing.", bundle: .module))
        }
        return try areaResult(
            rect: selection.rect,
            snapshot: snapshot,
            sourceApp: selection.window?.appName ?? sourceApp
        ).with(quickAction: selection.quickAction)
    }

    func interactiveWindow() async throws -> CaptureResult? {
        let windows = try await LocatedWindow.locate(snapshotter.listWindows())
        guard !windows.isEmpty else {
            throw CaptureError.captureFailed(String(localized: "No capturable windows are on screen.", bundle: .module))
        }
        guard let picked = await WindowPickerController(windows: windows).run() else {
            Log.capture.info("Window capture cancelled")
            return nil
        }
        return try await windowResult(for: picked)
    }

    func fullscreen(of screen: NSScreen?, sourceApp: String?) async throws -> CaptureResult {
        guard let screen, let snapshot = try await takeSnapshots(of: [screen]).first else {
            throw CaptureError.noDisplay
        }
        return makeResult(from: snapshot, sourceApp: sourceApp)
    }

    // MARK: - Results

    /// Crops `rect` out of a display snapshot and remembers it as the last area.
    func areaResult(rect: CGRect, snapshot: DisplaySnapshot, sourceApp: String?) throws -> CaptureResult {
        guard let image = CoordinateSpace.crop(snapshot.image, globalRect: rect, displayFrame: snapshot.frame) else {
            throw CaptureError.captureFailed(String(localized: "The selected area is empty.", bundle: .module))
        }
        if let displayID = snapshot.screen.displayID {
            lastAreaStore.save(LastArea(rect: rect, displayID: displayID))
        }
        return CaptureResult(image: image, scale: snapshot.scale, screenRect: rect, mode: .area, sourceAppName: sourceApp)
    }

    func windowResult(for window: LocatedWindow) async throws -> CaptureResult {
        let captured = try await snapshotter.captureWindow(
            window.info.windowID,
            includeShadow: settings.captureWindowShadow
        )
        return CaptureResult(
            image: captured.image,
            scale: captured.scale,
            screenRect: window.frame,
            mode: .window,
            sourceAppName: window.info.appName
        )
    }

    private func makeResult(from snapshot: DisplaySnapshot, sourceApp: String?) -> CaptureResult {
        CaptureResult(
            image: snapshot.image,
            scale: snapshot.scale,
            screenRect: snapshot.frame,
            mode: .fullscreen,
            sourceAppName: sourceApp
        )
    }

    // MARK: - Helpers

    func takeSnapshots(of screens: [NSScreen]) async throws -> [DisplaySnapshot] {
        guard !screens.isEmpty else { throw CaptureError.noDisplay }
        let frames = screens.map(\.frame)
        let requests = try screens.map { screen -> DisplayRequest in
            guard let displayID = screen.displayID else { throw CaptureError.noDisplay }
            return DisplayRequest(displayID: displayID, pointSize: screen.frame.size, scale: screen.backingScaleFactor)
        }
        let images = try await snapshotter.captureDisplays(requests)
        guard images.count == screens.count else {
            throw CaptureError.captureFailed(String(localized: "Some displays could not be captured.", bundle: .module))
        }
        return zip(zip(screens, frames), images).map { pair, image in
            let (screen, frame) = pair
            let scale = frame.width > 0 ? CGFloat(image.width) / frame.width : screen.backingScaleFactor
            return DisplaySnapshot(screen: screen, frame: frame, image: image, scale: scale)
        }
    }

    func screenUnderCursor() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    /// Name of the frontmost app, ignoring this app itself.
    func frontmostAppName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else { return nil }
        return app.localizedName
    }
}
