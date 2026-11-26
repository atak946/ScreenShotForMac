import AppKit
import ShotCore

/// Pixel ruler over a frozen snapshot of every display.
@MainActor
public final class MeasureTool: Measuring {
    private let snapshotProvider: @MainActor () async throws -> [CaptureResult]
    private let copyText: @MainActor (String) -> Void
    private var isRunning = false

    public init(
        snapshotProvider: @escaping @MainActor () async throws -> [CaptureResult],
        copyText: @escaping @MainActor (String) -> Void
    ) {
        self.snapshotProvider = snapshotProvider
        self.copyText = copyText
    }

    /// Shows the ruler and returns when the user exits (Esc / right click / app deactivation).
    public func startMeasuring() async throws {
        guard !isRunning else {
            Log.tools.info("Measure tool already active; ignoring request")
            return
        }
        isRunning = true
        defer { isRunning = false }

        let snapshots = try await snapshotProvider()
        guard !snapshots.isEmpty else { throw CaptureError.noDisplay }
        let buffers = await PixelBuffer.makeAll(from: snapshots)
        guard buffers.contains(where: { $0 != nil }) else {
            throw CaptureError.captureFailed(String(localized: "Unable to read snapshot pixels", bundle: .module))
        }

        let session = MeasureSession(snapshots: snapshots, buffers: buffers, copyText: copyText)
        await session.run()
        Log.tools.info("Measure tool finished")
    }
}
