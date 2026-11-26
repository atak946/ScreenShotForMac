import AppKit
import ApplicationServices

/// Finds snap targets under the cursor: Accessibility elements (when the app is trusted)
/// from innermost to outermost, ending with the owning window.
@MainActor
final class ElementLocator {
    private static let messagingTimeout: Float = 0.05
    private static let maxDepth = 12
    private static let minimumSide: CGFloat = 4

    private let isAccessibilityTrusted = AXIsProcessTrusted()
    private let primaryHeight = CoordinateSpace.primaryScreenHeight

    /// Candidate rects (global AppKit points), innermost first, deduplicated.
    func targets(at point: CGPoint, in window: LocatedWindow) -> [CGRect] {
        let elements = isAccessibilityTrusted ? elementFrames(at: point, in: window) : []
        return deduplicated(elements + [window.frame])
    }

    private func elementFrames(at point: CGPoint, in window: LocatedWindow) -> [CGRect] {
        guard window.info.processID > 0 else { return [] }
        let app = AXUIElementCreateApplication(window.info.processID)
        AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)

        let quartzY = primaryHeight - point.y
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(quartzY), &hit) == .success,
              var current = hit else { return [] }

        let limit = window.frame.insetBy(dx: -1, dy: -1)
        var frames: [CGRect] = []
        for _ in 0..<Self.maxDepth {
            if let frame = frame(of: current), isUseful(frame, limit: limit) {
                frames.append(frame)
            }
            if role(of: current) == kAXWindowRole as String { break }
            guard let parent = parent(of: current) else { break }
            current = parent
        }
        return frames
    }

    private func isUseful(_ frame: CGRect, limit: CGRect) -> Bool {
        frame.width >= Self.minimumSide && frame.height >= Self.minimumSide && limit.contains(frame)
    }

    private func deduplicated(_ rects: [CGRect]) -> [CGRect] {
        rects.reduce(into: [CGRect]()) { result, rect in
            let isDuplicate = result.contains { existing in
                abs(existing.minX - rect.minX) < 1 && abs(existing.minY - rect.minY) < 1
                    && abs(existing.width - rect.width) < 1 && abs(existing.height - rect.height) < 1
            }
            if !isDuplicate { result.append(rect) }
        }
    }

    // MARK: - AX attribute access

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = axValue(element, kAXPositionAttribute, type: .cgPoint, as: CGPoint.zero),
              let size = axValue(element, kAXSizeAttribute, type: .cgSize, as: CGSize.zero) else { return nil }
        let quartz = CGRect(origin: position, size: size)
        return CoordinateSpace.appKitRect(fromQuartz: quartz, primaryHeight: primaryHeight)
    }

    private func role(of element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute) as? String
    }

    private func parent(of element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(element, kAXParentAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func axValue<T: BitwiseCopyable>(_ element: AXUIElement, _ name: String, type: AXValueType, as initial: T) -> T? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        var result = initial
        guard AXValueGetValue(axValue, type, &result) else { return nil }
        return result
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
