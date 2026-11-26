import AppKit

/// Zoom (⌘+/-/0/1, pinch, ⌘-scroll) and pan (scroll, space-drag).
extension CanvasView {
    private static let minimumVisibleImage: CGFloat = 40
    private static let lineScrollMultiplier: CGFloat = 10

    func handleZoom(_ command: ZoomCommand) {
        let current = layout.zoom
        switch command {
        case .fit: setViewport(.fit)
        case .actualSize: zoom(to: 1, around: nil)
        case .zoomIn: zoom(to: CanvasViewport.nextStep(after: current), around: nil)
        case .zoomOut: zoom(to: CanvasViewport.previousStep(before: current), around: nil)
        case let .set(value): zoom(to: value, around: nil)
        }
    }

    /// Zooms keeping the document point under `anchor` (view coords; default center) fixed.
    func zoom(to newZoom: CGFloat, around anchor: CGPoint?) {
        let current = layout
        let zoom = CanvasViewport.clampZoom(newZoom)
        let anchorPoint = anchor ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let documentPoint = current.toDocument(anchorPoint)
        let centered = CanvasLayout(
            visibleRect: current.visibleRect, viewBounds: bounds, viewport: CanvasViewport(zoom: zoom, pan: .zero)
        )
        let desiredOrigin = CGPoint(
            x: anchorPoint.x - (documentPoint.x - current.visibleRect.minX) * zoom,
            y: anchorPoint.y - (documentPoint.y - current.visibleRect.minY) * zoom
        )
        setViewport(CanvasViewport(zoom: zoom, pan: desiredOrigin - centered.origin))
    }

    func pan(by delta: CGPoint) {
        let zoom = layout.zoom
        setViewport(CanvasViewport(zoom: viewport.zoom ?? zoom, pan: viewport.pan + delta))
    }

    func setViewport(_ newViewport: CanvasViewport) {
        viewport = clampedPan(newViewport)
        publishZoom()
        textEditor.reposition()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    func publishZoom() {
        let percent = Int((layout.zoom * 100).rounded())
        if viewModel.zoomPercent != percent { viewModel.zoomPercent = percent }
    }

    /// Keeps at least a sliver of the image inside the view.
    private func clampedPan(_ proposed: CanvasViewport) -> CanvasViewport {
        guard proposed.zoom != nil else { return proposed }
        let centered = CanvasLayout(
            visibleRect: viewModel.visibleRect, viewBounds: bounds, viewport: CanvasViewport(zoom: proposed.zoom, pan: .zero)
        )
        let frame = centered.imageFrame
        let margin = Self.minimumVisibleImage
        let minX = bounds.minX + margin - frame.maxX
        let maxX = bounds.maxX - margin - frame.minX
        let minY = bounds.minY + margin - frame.maxY
        let maxY = bounds.maxY - margin - frame.minY
        let pan = CGPoint(
            x: min(max(proposed.pan.x, minX), maxX),
            y: min(max(proposed.pan.y, minY), maxY)
        )
        return CanvasViewport(zoom: proposed.zoom, pan: pan)
    }

    // MARK: - Events

    override func magnify(with event: NSEvent) {
        let anchor = convert(event.locationInWindow, from: nil)
        zoom(to: layout.zoom * (1 + event.magnification), around: anchor)
    }

    override func smartMagnify(with event: NSEvent) {
        if viewport.zoom == nil {
            zoom(to: 1, around: convert(event.locationInWindow, from: nil))
        } else {
            setViewport(.fit)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let multiplier = event.hasPreciseScrollingDeltas ? 1 : Self.lineScrollMultiplier
        if event.modifierFlags.contains(.command) {
            let anchor = convert(event.locationInWindow, from: nil)
            let factor = exp(event.scrollingDeltaY * multiplier * 0.01)
            zoom(to: layout.zoom * factor, around: anchor)
            return
        }
        guard viewport.zoom != nil else {
            super.scrollWheel(with: event)
            return
        }
        pan(by: CGPoint(x: event.scrollingDeltaX * multiplier, y: event.scrollingDeltaY * multiplier))
    }
}
