import AppKit
import ShotCore
import SwiftUI

/// Declarative description of an `NSMenu` entry. Used by toolbar pop-up menus
/// and the canvas context menu so every menu looks and behaves the same.
struct MenuEntry {
    enum Kind {
        case action(@MainActor () -> Void)
        case submenu([MenuEntry])
        case header
        case separator
    }

    var title = ""
    var symbol: String?
    var image: NSImage?
    var isOn = false
    var isEnabled = true
    var keyEquivalent = ""
    var modifiers: NSEvent.ModifierFlags = []
    let kind: Kind

    static var separator: MenuEntry { MenuEntry(kind: .separator) }

    static func header(_ title: String) -> MenuEntry {
        MenuEntry(title: title, kind: .header)
    }

    static func action(
        _ title: String,
        symbol: String? = nil,
        image: NSImage? = nil,
        isOn: Bool = false,
        isEnabled: Bool = true,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        handler: @escaping @MainActor () -> Void
    ) -> MenuEntry {
        MenuEntry(
            title: title, symbol: symbol, image: image, isOn: isOn, isEnabled: isEnabled,
            keyEquivalent: key, modifiers: modifiers, kind: .action(handler)
        )
    }

    static func submenu(_ title: String, symbol: String? = nil, _ entries: [MenuEntry]) -> MenuEntry {
        MenuEntry(title: title, symbol: symbol, kind: .submenu(entries))
    }
}

/// Builds `NSMenu`s from `MenuEntry` lists.
@MainActor
enum MenuBuilder {
    static func menu(_ entries: [MenuEntry]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        entries.forEach { menu.addItem(item(for: $0)) }
        return menu
    }

    private static func item(for entry: MenuEntry) -> NSMenuItem {
        switch entry.kind {
        case .separator:
            return .separator()
        case .header:
            return NSMenuItem.sectionHeader(title: entry.title)
        case let .submenu(children):
            let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: "")
            item.image = image(for: entry)
            item.submenu = menu(children)
            return item
        case let .action(handler):
            let item = ActionMenuItem(title: entry.title, handler: handler)
            item.keyEquivalent = entry.keyEquivalent
            item.keyEquivalentModifierMask = entry.modifiers
            item.image = image(for: entry)
            item.state = entry.isOn ? .on : .off
            item.isEnabled = entry.isEnabled
            return item
        }
    }

    private static func image(for entry: MenuEntry) -> NSImage? {
        if let image = entry.image { return image }
        guard let symbol = entry.symbol else { return nil }
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }

    /// Round color swatch for menu items.
    static func swatch(_ color: AnnotationColor, diameter: CGFloat = 12) -> NSImage {
        NSImage(size: CGSize(width: diameter, height: diameter), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            color.nsColor.setFill()
            circle.fill()
            NSColor.black.withAlphaComponent(0.2).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }
}

/// Menu item that runs a closure; it is its own target.
@MainActor
private final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc
    private func fire() { handler() }
}

// MARK: - SwiftUI anchoring

/// Remembers the AppKit view behind a SwiftUI control so a menu can pop up below it.
@MainActor
final class MenuAnchor {
    fileprivate weak var view: NSView?

    func popUp(_ entries: [MenuEntry]) {
        guard let view else { return }
        let menu = MenuBuilder.menu(entries)
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.bounds.maxY + 4), in: view)
    }
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> AnchorNSView {
        let view = AnchorNSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: AnchorNSView, context: Context) {
        anchor.view = nsView
    }

    final class AnchorNSView: NSView {
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

extension View {
    func menuAnchor(_ anchor: MenuAnchor) -> some View {
        background(MenuAnchorView(anchor: anchor))
    }
}

/// Toolbar control that opens a pop-up menu below itself.
struct PopUpMenuButton<Label: View>: View {
    let help: String
    var isSelected = false
    let entries: () -> [MenuEntry]
    @ViewBuilder let label: () -> Label
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button { anchor.popUp(entries()) } label: { label() }
            .buttonStyle(ChromeButtonStyle(isSelected: isSelected))
            .menuAnchor(anchor)
            .help(help)
            .accessibilityLabel(help)
    }
}

/// Small chevron used next to icons that open a menu.
struct MenuChevron: View {
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 7, weight: .bold))
            .opacity(0.7)
    }
}

// MARK: - Button style

/// Variable-width sibling of `ToolButtonStyle`: hover fill, pressed scale, selected = accent.
struct ChromeButtonStyle: ButtonStyle {
    var isSelected = false
    var height: CGFloat = DS.Size.iconButton

    func makeBody(configuration: Configuration) -> some View {
        ChromeButtonBody(configuration: configuration, isSelected: isSelected, height: height)
    }
}

private struct ChromeButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let height: CGFloat
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, DS.Space.s - 2)
            .frame(minWidth: height, minHeight: height, maxHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor) }
        if configuration.isPressed { return AnyShapeStyle(Color.primary.opacity(0.16)) }
        return AnyShapeStyle(Color.primary.opacity(isHovering ? 0.08 : 0))
    }
}

// MARK: - Window dragging

/// Background for custom titlebar content: drags the window, double-click zooms/minimizes
/// following the user's "double-click a window's title bar" preference.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
                case "Minimize": window.performMiniaturize(nil)
                case "None": break
                default: window.performZoom(nil)
                }
                return
            }
            window.performDrag(with: event)
        }
    }
}
