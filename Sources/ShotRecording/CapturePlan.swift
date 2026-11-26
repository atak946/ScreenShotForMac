import AVFoundation
import CoreGraphics
import CoreVideo
@preconcurrency import ScreenCaptureKit
import ShotCore

/// Everything needed to configure the SCStream, as plain Sendable values.
struct CapturePlan: Sendable {
    let target: RecordingTarget
    let outputWidth: Int
    let outputHeight: Int
    let framesPerSecond: Int
    let showsCursor: Bool
    let capturesSystemAudio: Bool
    let capturesMicrophone: Bool
    let pixelFormat: OSType
    /// Windows of this app that must stay visible in the capture (click highlights, webcam, keystrokes).
    let includedOwnWindowIDs: [CGWindowID]
}

/// Builds SCK filter / configuration objects. Only used inside nonisolated capture code.
enum CaptureFilterFactory {
    static func filter(for plan: CapturePlan, content: SCShareableContent) throws -> SCContentFilter {
        guard let display = content.displays.first(where: { $0.displayID == plan.target.displayID }) else {
            throw CaptureError.noDisplay
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let included = Set(plan.includedOwnWindowIDs)
        let keptOwnWindows = content.windows.filter { included.contains($0.windowID) }
        if keptOwnWindows.count < included.count {
            Log.recording.warning("Some overlay windows were not found in shareable content")
        }

        switch plan.target.kind {
        case .display, .area:
            let ownApps = content.applications.filter { $0.processID == ownPID }
            return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: keptOwnWindows)
        case let .window(windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw CaptureError.captureFailed(String(localized: "The selected window is no longer available.", bundle: .module))
            }
            return SCContentFilter(display: display, including: [window] + keptOwnWindows)
        }
    }

    static func configuration(for plan: CapturePlan) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = plan.outputWidth
        config.height = plan.outputHeight
        if !plan.target.isFullDisplay {
            config.sourceRect = plan.target.sourceRect
        }
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, plan.framesPerSecond)))
        config.showsCursor = plan.showsCursor
        config.pixelFormat = plan.pixelFormat
        config.colorSpaceName = CGColorSpace.sRGB
        if plan.pixelFormat != kCVPixelFormatType_32BGRA {
            config.colorMatrix = kCVImageBufferYCbCrMatrix_ITU_R_709_2
        }
        config.scalesToFit = true
        config.preservesAspectRatio = true
        config.queueDepth = 6
        config.backgroundColor = .black

        if plan.capturesSystemAudio {
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.excludesCurrentProcessAudio = true
        }
        if plan.capturesMicrophone, #available(macOS 15.0, *) {
            config.captureMicrophone = true
            config.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        }
        return config
    }
}
