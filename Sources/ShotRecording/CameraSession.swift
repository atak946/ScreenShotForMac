@preconcurrency import AVFoundation
import ShotCore

/// Wraps an `AVCaptureSession` fed by the default video device.
/// `startRunning` / `stopRunning` block, so they run on a private serial queue;
/// the session itself is only configured once, before it is shared with that queue.
final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.screenshotformac.recording.camera")

    /// Returns nil when no camera is available or it cannot be opened.
    init?() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            Log.recording.info("No camera available for the webcam overlay")
            return nil
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .high
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                Log.recording.error("Camera input cannot be added to the capture session")
                return nil
            }
            session.addInput(input)
            session.commitConfiguration()
        } catch {
            Log.recording.error("Camera could not be opened: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func start() {
        queue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}
