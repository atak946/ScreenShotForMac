import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit
import ShotCore

/// A CGImage that may cross isolation boundaries. CGImage is immutable.
struct SendableImage: @unchecked Sendable {
    let cgImage: CGImage
}

/// Plain description of the region to capture.
struct GrabRequest: Sendable {
    let displayID: CGDirectDisplayID
    /// Region in display-local points, top-left origin (ScreenCaptureKit `sourceRect`).
    let sourceRect: CGRect
    /// Pixels per point.
    let scale: CGFloat
}

/// Repeatedly captures a fixed display region with ScreenCaptureKit, excluding this app's windows.
/// SCK objects never leave the actor.
actor FrameGrabber {
    private let filter: SCContentFilter
    private let configuration: SCStreamConfiguration

    private init(filter: SCContentFilter, configuration: SCStreamConfiguration) {
        self.filter = filter
        self.configuration = configuration
    }

    static func make(_ request: GrabRequest) async throws -> FrameGrabber {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            Log.capture.error("Failed to load shareable content: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.captureFailed(error.localizedDescription)
        }
        guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
            throw CaptureError.noDisplay
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == ownPID }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        return FrameGrabber(filter: filter, configuration: makeConfiguration(request))
    }

    func grab() async throws -> SendableImage {
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return SendableImage(cgImage: image)
        } catch {
            Log.capture.error("Scrolling frame capture failed: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private static func makeConfiguration(_ request: GrabRequest) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.sourceRect = request.sourceRect
        config.width = max(1, Int((request.sourceRect.width * request.scale).rounded()))
        config.height = max(1, Int((request.sourceRect.height * request.scale).rounded()))
        config.showsCursor = false
        config.captureResolution = .best
        config.scalesToFit = false
        return config
    }
}
