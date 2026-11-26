import AppKit
import ShotCore

/// Mouse and keyboard handling for `MeasureSession`.
extension MeasureSession: MeasureOverlayDelegate {
    private enum KeyCode {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let tab: UInt16 = 48
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    // MARK: Mouse

    func overlayMouseMoved() {
        locate(NSEvent.mouseLocation)
    }

    func overlayMouseDown() {
        let global = NSEvent.mouseLocation
        guard let index = displayIndex(at: global) ?? cursor?.display else { return }
        drag = DragStart(display: index, global: global, isDragging: false)
        locate(global)
    }

    func overlayMouseDragged() {
        let global = NSEvent.mouseLocation
        guard let start = drag else {
            locate(global)
            return
        }
        let distance = hypot(global.x - start.global.x, global.y - start.global.y)
        if !start.isDragging, distance < Self.dragThreshold { return }
        drag = DragStart(display: start.display, global: start.global, isDragging: true)
        updateDragBox(to: global)
        locate(global)
    }

    func overlayMouseUp() {
        defer { drag = nil }
        guard let start = drag else { return }
        if start.isDragging {
            updateDragBox(to: NSEvent.mouseLocation)
            refresh()
            return
        }
        handleClick()
    }

    func overlayCancelled() {
        finish()
    }

    func overlayModifiersChanged() {
        if drag?.isDragging == true { updateDragBox(to: NSEvent.mouseLocation) }
        refresh()
    }

    private func updateDragBox(to global: CGPoint) {
        guard let start = drag, displays.indices.contains(start.display) else { return }
        let raw = displays[start.display].geometry.pixelRect(fromGlobal: start.global, to: global)
        let snapped = NSEvent.modifierFlags.contains(.option)
            ? scanner(for: start.display).contentBounds(in: raw)
            : nil
        box = Box(display: start.display, rect: snapped ?? raw, isSnapped: snapped != nil)
    }

    /// Click inside the box copies its size; otherwise copies the hover measurement and clears the box.
    private func handleClick() {
        guard let cursor else { return }
        if let box, box.display == cursor.display, box.rect.contains(cursor.pixel) {
            copy(width: box.rect.width, height: box.rect.height, display: box.display)
            return
        }
        box = nil
        copyHover()
    }

    private func copyHover() {
        guard let cursor else { return }
        let span = scanner(for: cursor.display).span(around: cursor.pixel)
        copy(width: span.width, height: span.height, display: cursor.display)
    }

    private func copy(width: Int, height: Int, display: Int) {
        let text = formatter(for: display).copyText(width: width, height: height)
        copyText(text)
        Log.tools.info("Measure: copied measurement")
        showBadge(String(localized: "Copied \(text)", bundle: .module), on: display)
    }

    // MARK: Keyboard

    func overlayKeyDown(_ event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? Self.shiftStep : 1
        switch event.keyCode {
        case KeyCode.escape: finish()
        case KeyCode.returnKey, KeyCode.keypadEnter: copyHover()
        case KeyCode.tab: toggleUnit()
        case KeyCode.left: move(dx: -step, dy: 0)
        case KeyCode.right: move(dx: step, dy: 0)
        case KeyCode.up: move(dx: 0, dy: -step)
        case KeyCode.down: move(dx: 0, dy: step)
        default: handleCharacter(event.charactersIgnoringModifiers)
        }
    }

    private func handleCharacter(_ characters: String?) {
        switch characters {
        case "[": adjustTolerance(by: -Self.toleranceStep)
        case "]": adjustTolerance(by: Self.toleranceStep)
        default: break
        }
    }

    private func toggleUnit() {
        unit = unit.toggled
        guard let cursor else { return }
        let title = unit == .points ? String(localized: "Points", bundle: .module) : String(localized: "Pixels", bundle: .module)
        showBadge(title, on: cursor.display)
    }

    private func adjustTolerance(by delta: Int) {
        let range = EdgeScanner.toleranceRange
        tolerance = min(max(tolerance + delta, range.lowerBound), range.upperBound)
        if let cursor { showBadge(String(localized: "Tolerance \(tolerance)", bundle: .module), on: cursor.display) }
    }

    private func move(dx: Int, dy: Int) {
        guard let cursor, displays.indices.contains(cursor.display) else { return }
        let geometry = displays[cursor.display].geometry
        let pixel = geometry.clamped(x: cursor.pixel.x + dx, y: cursor.pixel.y + dy)
        self.cursor = Cursor(display: cursor.display, pixel: pixel)
        warpCursor(to: geometry.globalPoint(forPixelCenter: pixel))
        refresh()
    }

    /// Moves the system cursor; CG uses a top-left origin relative to the primary display.
    private func warpCursor(to point: CGPoint) {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: primaryHeight - point.y))
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
