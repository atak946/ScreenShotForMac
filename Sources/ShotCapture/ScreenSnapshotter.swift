import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit
import ShotCore

/// Describes one display to snapshot. Plain values so it can cross isolation boundaries.
struct DisplayRequest: Sendable {
    let displayID: CGDirectDisplayID
    /// Display size in points.
    let pointSize: CGSize
    /// Backing scale factor (pixels per point).
    let scale: CGFloat
}

/// A capturable on-screen window, in front-to-back order when listed.
struct WindowInfo: Sendable, Equatable {
    let windowID: CGWindowID
    /// Window frame in CG global coordinates (top-left origin, points).
    let quartzFrame: CGRect
    let processID: pid_t
    let appName: String?
    let title: String?
}

/// A window capture together with its pixel scale.
struct WindowImage: @unchecked Sendable {
    let image: CGImage
    let scale: CGFloat
}

/// Wraps a non-Sendable value that is never mutated after creation so it can be
/// handed to a child task. Used for SCK filter / configuration objects.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
}

/// Thin ScreenCaptureKit wrapper. Every SCK object stays inside this type's
/// nonisolated async functions; only Sendable values leave it.
struct ScreenSnapshotter: Sendable {
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// Captures the given displays in parallel (excluding this app's windows), preserving request order.
    func captureDisplays(_ requests: [DisplayRequest]) async throws -> [CGImage] {
        let content = try await shareableContent()
        let ownApps = content.applications.filter { $0.processID == ownPID }
        let jobs = try requests.map { request in
            guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
                throw CaptureError.noDisplay
            }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            return UncheckedBox(value: (filter, Self.displayConfiguration(for: request)))
        }
        return try await withThrowingTaskGroup(of: (Int, CGImage).self) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask {
                    let image = try await screenshot(filter: job.value.0, config: job.value.1)
                    return (index, image)
                }
            }
            var images = [CGImage?](repeating: nil, count: jobs.count)
            for try await (index, image) in group {
                images[index] = image
            }
            return images.compactMap(\.self)
        }
    }

    /// Lists normal, on-screen windows of other apps, front-most first.
    func listWindows() async throws -> [WindowInfo] {
        let content = try await shareableContent()
        let candidates = content.windows.filter(isPickable)
        let byID = Dictionary(candidates.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = Self.frontToBackWindowIDs().compactMap { byID[$0] }
        // Fall back to SCK order for anything the CG list did not report.
        let orderedIDs = Set(ordered.map(\.windowID))
        let remaining = candidates.filter { !orderedIDs.contains($0.windowID) }
        return (ordered + remaining).map(Self.info(for:))
    }

    /// Captures a single window independent of what covers it.
    func captureWindow(_ windowID: CGWindowID, includeShadow: Bool) async throws -> WindowImage {
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.captureFailed(String(localized: "The selected window is no longer available.", bundle: .module))
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = max(1, Int((filter.contentRect.width * scale).rounded()))
        config.height = max(1, Int((filter.contentRect.height * scale).rounded()))
        config.showsCursor = false
        config.captureResolution = .best
        config.ignoreShadowsSingleWindow = !includeShadow
        config.ignoreGlobalClipSingleWindow = true
        config.shouldBeOpaque = false
        let image = try await screenshot(filter: filter, config: config)
        return WindowImage(image: image, scale: scale)
    }

    // MARK: - Private

    private static func displayConfiguration(for request: DisplayRequest) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(1, Int((request.pointSize.width * request.scale).rounded()))
        config.height = max(1, Int((request.pointSize.height * request.scale).rounded()))
        config.showsCursor = false
        config.captureResolution = .best
        return config
    }

    private func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        } catch {
            Log.capture.error("Failed to load shareable content: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func screenshot(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            Log.capture.error("Screenshot failed: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func isPickable(_ window: SCWindow) -> Bool {
        guard window.isOnScreen, window.windowLayer == 0, window.frame.width > 1, window.frame.height > 1,
              let app = window.owningApplication else { return false }
        return app.processID != ownPID
    }

    private static func info(for window: SCWindow) -> WindowInfo {
        WindowInfo(
            windowID: window.windowID,
            quartzFrame: window.frame,
            processID: window.owningApplication?.processID ?? 0,
            appName: window.owningApplication?.applicationName,
            title: window.title
        )
    }

    /// Window IDs in z-order (front-most first) from the window server.
    private static func frontToBackWindowIDs() -> [CGWindowID] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
    }
}
