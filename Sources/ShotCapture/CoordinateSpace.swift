import AppKit
import CoreGraphics

/// Conversion helpers between the coordinate systems used during capture.
///
/// - AppKit global: points, origin at bottom-left of the primary display, y grows up.
/// - CG / Quartz global: points, origin at top-left of the primary display, y grows down.
/// - Image pixels: origin at top-left of a display snapshot, y grows down.
enum CoordinateSpace {
    /// Height of the primary (menu bar) display, the pivot for the global y flip.
    @MainActor static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Converts a rect in CG global coordinates (top-left origin) to AppKit global coordinates.
    static func appKitRect(fromQuartz rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a global AppKit rect to a pixel rect inside a display snapshot.
    /// `displayFrame` is the display's AppKit frame; `pixelScale` is image pixels per point.
    static func pixelRect(
        forGlobalRect rect: CGRect,
        displayFrame: CGRect,
        pixelScale: CGFloat
    ) -> CGRect {
        let localX = rect.minX - displayFrame.minX
        let localTop = displayFrame.maxY - rect.maxY
        return CGRect(
            x: localX * pixelScale,
            y: localTop * pixelScale,
            width: rect.width * pixelScale,
            height: rect.height * pixelScale
        ).integral
    }

    /// Converts a global AppKit point to an integer pixel coordinate inside a display snapshot.
    static func pixelPoint(
        forGlobalPoint point: CGPoint,
        displayFrame: CGRect,
        pixelScale: CGFloat
    ) -> (x: Int, y: Int) {
        let localX = (point.x - displayFrame.minX) * pixelScale
        let localTop = (displayFrame.maxY - point.y) * pixelScale
        return (Int(localX.rounded(.down)), Int(localTop.rounded(.down)))
    }

    /// Crops a global AppKit rect out of a display snapshot. Returns nil when the rect misses the image.
    static func crop(
        _ image: CGImage,
        globalRect: CGRect,
        displayFrame: CGRect
    ) -> CGImage? {
        guard displayFrame.width > 0 else { return nil }
        let scale = CGFloat(image.width) / displayFrame.width
        let pixel = pixelRect(forGlobalRect: globalRect, displayFrame: displayFrame, pixelScale: scale)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clipped = pixel.intersection(bounds)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        return image.cropping(to: clipped)
    }
}

extension NSScreen {
    /// The CoreGraphics display ID backing this screen.
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

extension CGRect {
    /// Standardized rect spanning two points.
    init(corner a: CGPoint, corner b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
