import AppKit
import ImageIO
import ShotCore
import UniformTypeIdentifiers

/// Builds the right-click menu for a pin and performs its actions.
@MainActor
enum PinContextMenu {
    private static let opacityLevels = stride(from: 100, through: 10, by: -10).map(\.self)

    static func make(for panel: PinPanel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: String(localized: "Image", bundle: .module)))
        menu.addItem(item(String(localized: "Copy", bundle: .module), symbol: "doc.on.doc") { [weak panel] in
            panel.map(copy)
        })
        menu.addItem(item(String(localized: "Save…", bundle: .module), symbol: "square.and.arrow.down") { [weak panel] in
            panel.map(save)
        })
        menu.addItem(item(String(localized: "Rotate 90°", bundle: .module), symbol: "rotate.right") { [weak panel] in
            panel?.rotateClockwise()
        })
        menu.addItem(item(String(localized: "Actual Size", bundle: .module), symbol: "1.magnifyingglass") { [weak panel] in
            panel?.resetZoom()
        })
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: String(localized: "View", bundle: .module)))
        menu.addItem(opacityItem(for: panel))
        menu.addItem(item(String(localized: "Click-through", bundle: .module), symbol: "cursorarrow.rays") { [weak panel] in
            panel?.setClickThrough(true)
        })
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Close", bundle: .module), symbol: "xmark") { [weak panel] in
            panel?.dismiss()
        })
        menu.addItem(item(String(localized: "Close All Pins", bundle: .module), symbol: "pin.slash") { [weak panel] in
            panel?.requestCloseAll()
        })
        return menu
    }

    private static func item(_ title: String, symbol: String, handler: @escaping () -> Void) -> ActionMenuItem {
        let item = ActionMenuItem(title: title, handler: handler)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private static func opacityItem(for panel: PinPanel) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: "Opacity", bundle: .module), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)
        let submenu = NSMenu()
        let current = Int((panel.alphaValue * 100).rounded())
        for level in opacityLevels {
            let entry = ActionMenuItem(title: "\(level)%") { [weak panel] in
                panel?.setOpacity(CGFloat(level) / 100)
            }
            entry.state = abs(current - level) < 5 ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private static func copy(_ panel: PinPanel) {
        let image = NSImage(cgImage: panel.image, size: panel.baseSize)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.writeObjects([image]) {
            Log.editor.error("Pin copy to clipboard failed")
        }
    }

    private static func save(_ panel: PinPanel) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = String(localized: "Pinned Screenshot", bundle: .module) + ".png"
        savePanel.level = .modalPanel
        NSApp.activate()
        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }
        do {
            try writePNG(panel.image, to: url)
            Log.editor.info("Saved pinned image")
        } catch {
            Log.editor.error("Saving pinned image failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { throw PinSaveError.destinationUnavailable }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PinSaveError.encodingFailed }
    }
}

enum PinSaveError: LocalizedError {
    case destinationUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .destinationUnavailable: return String(localized: "Could not create the image file.", bundle: .module)
        case .encodingFailed: return String(localized: "Could not encode the image as PNG.", bundle: .module)
        }
    }
}

/// NSMenuItem that runs a closure.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc
    private func run() {
        handler()
    }
}
