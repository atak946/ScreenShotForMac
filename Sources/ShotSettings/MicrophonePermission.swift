import AVFoundation
import Observation
import ShotCore

/// Observable microphone authorization state.
@MainActor
@Observable
final class MicrophonePermission {
    private(set) var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var isGranted: Bool { status == .authorized }
    var canRequest: Bool { status == .notDetermined }

    func refresh() {
        status = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func request() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        Log.settings.info("Microphone access granted: \(granted)")
        refresh()
    }
}
