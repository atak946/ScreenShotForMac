import AppKit
import CoreGraphics

/// What the user picked to record. Plain values so it can cross isolation boundaries.
struct RecordingTarget: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case display
        case area
        case window(CGWindowID)
    }

    let kind: Kind
    let displayID: CGDirectDisplayID
    /// Display frame in global AppKit points.
    let displayFrame: CGRect
    /// Recorded rect in global AppKit points, always inside `displayFrame`.
    let rect: CGRect
    /// Backing scale factor of the display (pixels per point).
    let scale: CGFloat

    /// Minimum recordable side length in points.
    static let minimumSide: CGFloat = 8
    /// GIF frames are downsampled to at most this many pixels wide.
    static let gifMaxWidth: CGFloat = 960

    /// Builds a target clipped to `screen`. Returns nil when the clipped rect is too small.
    @MainActor
    static func make(kind: Kind, rect: CGRect, screen: NSScreen) -> RecordingTarget? {
        guard let displayID = screen.recordingDisplayID else { return nil }
        let clipped = rect.integral.intersection(screen.frame)
        guard !clipped.isNull, clipped.width >= minimumSide, clipped.height >= minimumSide else { return nil }
        return RecordingTarget(
            kind: kind,
            displayID: displayID,
            displayFrame: screen.frame,
            rect: clipped,
            scale: screen.backingScaleFactor
        )
    }

    /// Recorded rect in display-local points with a top-left origin (SCK `sourceRect`).
    var sourceRect: CGRect {
        CGRect(
            x: rect.minX - displayFrame.minX,
            y: displayFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    var isFullDisplay: Bool {
        if case .display = kind { return true }
        return false
    }

    /// Even output pixel size, optionally limited to `maxWidth` pixels (aspect preserved).
    func outputPixelSize(maxWidth: CGFloat? = nil) -> (width: Int, height: Int) {
        var width = rect.width * scale
        var height = rect.height * scale
        if let maxWidth, width > maxWidth {
            height *= maxWidth / width
            width = maxWidth
        }
        return (RecordingGeometry.even(width), RecordingGeometry.even(height))
    }
}
