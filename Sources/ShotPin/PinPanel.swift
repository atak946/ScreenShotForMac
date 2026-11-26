import AppKit
import ShotCore

/// A borderless, always-on-top, non-activating panel showing one pinned image.
@MainActor
final class PinPanel: NSPanel {
    static let minZoom: CGFloat = 0.1
    static let maxZoom: CGFloat = 4.0
    private static let minOpacity: CGFloat = 0.1

    private weak var owner: PinPanelOwner?
    private let pinView: PinContentView
    private(set) var image: CGImage
    private let scale: CGFloat
    private(set) var zoom: CGFloat = 1
    private(set) var isClickThrough = false

    init(image: CGImage, scale: CGFloat, owner: PinPanelOwner) {
        self.image = image
        self.scale = max(scale, 1)
        self.owner = owner
        pinView = PinContentView(image: image)
        let size = CGSize(width: CGFloat(image.width) / self.scale, height: CGFloat(image.height) / self.scale)
        super.init(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureWindow()
        pinView.delegate = self
        contentView = pinView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Size of the (possibly rotated) image in points at 100% zoom.
    var baseSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    func present() {
        orderFrontRegardless()
        makeKey()
    }

    func place(origin: CGPoint, zoom newZoom: CGFloat) {
        zoom = clampZoom(newZoom)
        let size = CGSize(width: baseSize.width * zoom, height: baseSize.height * zoom)
        setFrame(CGRect(origin: origin, size: size), display: true)
    }

    func dismiss(notifyOwner: Bool = true) {
        orderOut(nil)
        if notifyOwner {
            owner?.pinDidClose(self)
        }
    }

    // MARK: Zoom / opacity / rotation

    /// Zooms keeping the screen point `anchor` fixed.
    func setZoom(_ newZoom: CGFloat, anchor: CGPoint) {
        let clamped = clampZoom(newZoom)
        guard clamped != zoom else { return }
        let old = frame
        let fx = old.width > 0 ? (anchor.x - old.minX) / old.width : 0.5
        let fy = old.height > 0 ? (anchor.y - old.minY) / old.height : 0.5
        let size = CGSize(width: baseSize.width * clamped, height: baseSize.height * clamped)
        let origin = CGPoint(x: anchor.x - fx * size.width, y: anchor.y - fy * size.height)
        zoom = clamped
        setFrame(CGRect(origin: origin, size: size), display: true)
        invalidateShadow()
        pinView.showHUD("\(Int((zoom * 100).rounded()))%")
    }

    func resetZoom() {
        setZoom(1, anchor: CGPoint(x: frame.midX, y: frame.midY))
    }

    func setOpacity(_ value: CGFloat) {
        alphaValue = min(1, max(Self.minOpacity, value))
        pinView.showHUD(String(localized: "Opacity \(Int((alphaValue * 100).rounded()))%", bundle: .module))
    }

    func rotateClockwise() {
        guard let rotated = PinImageOps.rotatedClockwise(image) else {
            Log.editor.error("Pin rotation failed")
            return
        }
        image = rotated
        pinView.setImage(rotated)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let size = CGSize(width: baseSize.width * zoom, height: baseSize.height * zoom)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        setFrame(CGRect(origin: origin, size: size), display: true)
        invalidateShadow()
    }

    func setClickThrough(_ enabled: Bool) {
        isClickThrough = enabled
        ignoresMouseEvents = enabled
        pinView.setHoverEnabled(!enabled)
        owner?.pinClickThroughDidChange()
    }

    func requestCloseAll() {
        owner?.pinRequestsCloseAll()
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if !handleKey(event) {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let chars = event.charactersIgnoringModifiers, chars.count == 1 else { return false }
        if event.keyCode == KeyCode.escape {
            dismiss()
            return true
        }
        if flags.contains(.command) {
            guard chars == "0" else { return false }
            resetZoom()
            return true
        }
        guard flags.isDisjoint(with: [.control, .option]), let digit = Int(chars) else { return false }
        setOpacity(digit == 0 ? 1 : CGFloat(digit) / 10)
        return true
    }

    // MARK: Private

    private func configureWindow() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = true
        animationBehavior = .utilityWindow
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(Self.maxZoom, max(Self.minZoom, value))
    }

    private enum KeyCode {
        static let escape: UInt16 = 53
    }
}

// MARK: - PinContentViewDelegate

extension PinPanel: PinContentViewDelegate {
    func pinContentDidRequestClose() {
        dismiss()
    }

    func pinContentDidScroll(zoomDelta: CGFloat, anchor: CGPoint) {
        setZoom(zoom * zoomDelta, anchor: anchor)
    }

    func pinContentDidScrollOpacity(delta: CGFloat) {
        setOpacity(alphaValue + delta)
    }

    func pinContentMenu() -> NSMenu {
        PinContextMenu.make(for: self)
    }
}

/// Pure image helpers for pins.
enum PinImageOps {
    /// Returns the image rotated 90° clockwise, or nil if a context could not be created.
    static func rotatedClockwise(_ image: CGImage) -> CGImage? {
        let width = image.height
        let height = image.width
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.rotate(by: -.pi / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
