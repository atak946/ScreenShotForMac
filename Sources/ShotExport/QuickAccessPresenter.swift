import AppKit
import ShotCore

/// CleanShot-style floating thumbnails stacked at the bottom-left of the active screen.
@MainActor
public final class QuickAccessPresenter: QuickAccessPresenting {
    private static let maxItems = 4
    private static let thumbnailWidth: CGFloat = 220
    private static let maxThumbnailHeight: CGFloat = 200
    private static let margin: CGFloat = 16
    private static let spacing: CGFloat = 12

    private let settings: AppSettings
    private let dragExporter = DragExporter()
    private let template = FilenameTemplate()
    private var items: [QuickAccessItem] = []
    private var visibleFrame: NSRect = .zero

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public func show(_ capture: CaptureResult, handlers: QuickAccessHandlers) {
        visibleFrame = Self.activeScreen()?.visibleFrame ?? .zero
        let active = items.filter { !$0.isDismissing }
        if active.count >= Self.maxItems {
            active.prefix(active.count - Self.maxItems + 1).forEach { $0.dismiss() }
        }
        let size = ImageScaler.fitting(
            capture.pointSize,
            width: Self.thumbnailWidth,
            maxHeight: Self.maxThumbnailHeight
        )
        let item = QuickAccessItem(
            capture: capture,
            handlers: handlers,
            size: size,
            configuration: configuration(for: capture),
            onDismissed: { [weak self] dismissed in self?.remove(dismissed) }
        )
        items.append(item)
        let origins = layoutOrigins()
        relayout(origins, except: item)
        item.present(at: origins[ObjectIdentifier(item)] ?? .zero, offscreenX: visibleFrame.minX - size.width)
    }

    public func dismissAll() {
        items.forEach { $0.dismiss() }
    }

    // MARK: Layout

    private func remove(_ item: QuickAccessItem) {
        items.removeAll { $0 === item }
        relayout(layoutOrigins(), except: nil)
    }

    private func relayout(_ origins: [ObjectIdentifier: NSPoint], except skipped: QuickAccessItem?) {
        for item in items where item !== skipped {
            if let origin = origins[ObjectIdentifier(item)] { item.move(to: origin) }
        }
    }

    /// Newest item sits at the bottom; older ones stack upward.
    private func layoutOrigins() -> [ObjectIdentifier: NSPoint] {
        var result: [ObjectIdentifier: NSPoint] = [:]
        var y = visibleFrame.minY + Self.margin
        for item in items.reversed() where !item.isDismissing {
            result[ObjectIdentifier(item)] = NSPoint(x: visibleFrame.minX + Self.margin, y: y)
            y += item.size.height + Self.spacing
        }
        return result
    }

    private func configuration(for capture: CaptureResult) -> QuickAccessConfiguration {
        let context = FilenameContext(date: capture.capturedAt, appName: capture.sourceAppName)
        let counter = UserDefaults.standard.integer(forKey: FilenameTemplate.counterKey)
        return QuickAccessConfiguration(
            dragExporter: dragExporter,
            dragBaseName: template.render(template: settings.filenameTemplate, context: context, counter: counter),
            autoCloseSeconds: settings.quickAccessAutoCloseSeconds
        )
    }

    private static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}
