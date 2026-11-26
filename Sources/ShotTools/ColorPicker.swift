import AppKit
import ShotCore

/// Full-screen magnifier color picker over a frozen snapshot of every display.
@MainActor
public final class ColorPicker: ColorPicking {
    private let snapshotProvider: @MainActor () async throws -> [CaptureResult]
    private let settings: AppSettings
    private var isRunning = false

    public init(
        snapshotProvider: @escaping @MainActor () async throws -> [CaptureResult],
        settings: AppSettings = .shared
    ) {
        self.snapshotProvider = snapshotProvider
        self.settings = settings
    }

    /// Returns the picked color (sRGB), or nil when cancelled or already running.
    public func pickColor() async throws -> PickedColor? {
        guard !isRunning else {
            Log.tools.info("Color picker already active; ignoring request")
            return nil
        }
        isRunning = true
        defer { isRunning = false }
        let snapshots = try await snapshotProvider()
        guard !snapshots.isEmpty else { throw CaptureError.noDisplay }

        let session = ColorPickerSession(snapshots: snapshots, format: settings.colorFormat)
        let color = await session.run()
        Log.tools.info("Color picker finished, picked: \(color != nil, privacy: .public)")
        return color
    }
}
