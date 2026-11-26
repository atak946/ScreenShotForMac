import AppKit

/// Multi-selection: Shift / ⌘ toggling, group moves and rubber-band (marquee) selection.
extension CanvasView {
    private static let groupOutlineInset: CGFloat = -4
    private static let itemOutlineInset: CGFloat = -2

    /// Select-tool mouse down. `extending` = Shift or ⌘ held.
    func beginSelectAction(at point: CGPoint, hit: Annotation?, extending: Bool) {
        let selection = viewModel.selectedIDs
        guard let hit else {
            if !extending { viewModel.selectedIDs = [] }
            dragState = .marquee(origin: point, base: extending ? selection : [])
            marqueeRect = CGRect(origin: point, size: .zero)
            return
        }
        if extending {
            viewModel.selectedIDs = selection.symmetricDifference([hit.id])
            return
        }
        if selection.count > 1, selection.contains(hit.id) {
            dragState = .movingGroup(ids: selection, last: point, snapshot: viewModel.document)
            return
        }
        viewModel.selectedID = hit.id
        let part = HitTesting.movePart(of: hit, at: point)
        dragState = .moving(id: hit.id, part: part, last: point, snapshot: viewModel.document)
    }

    func updateMarquee(from origin: CGPoint, to point: CGPoint, base: Set<UUID>) {
        let rect = Geometry.rect(from: origin, to: point)
        marqueeRect = rect
        let inside = viewModel.document.annotations
            .filter { HitTesting.bounds(of: $0).intersects(rect) }
            .map(\.id)
        let selection = base.union(inside)
        if selection != viewModel.selectedIDs { viewModel.selectedIDs = selection }
    }

    func endMarquee() {
        marqueeRect = nil
    }

    // MARK: - Drawing

    /// Several selected: thin outline per item plus a dashed box around the group (no handles).
    func drawGroupSelection(layout: CanvasLayout, in context: CGContext) {
        let selected = viewModel.selectedAnnotations
        guard selected.count > 1 else { return }
        let frames = selected.map { layout.toView(HitTesting.bounds(of: $0)) }
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1)
        frames.forEach { context.stroke($0.insetBy(dx: Self.itemOutlineInset, dy: Self.itemOutlineInset)) }
        if let union = frames.dropFirst().reduce(frames.first, { $0?.union($1) }) {
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(union.insetBy(dx: Self.groupOutlineInset, dy: Self.groupOutlineInset))
        }
        context.restoreGState()
    }

    func drawMarquee(layout: CanvasLayout, in context: CGContext) {
        guard let marqueeRect else { return }
        let frame = layout.toView(marqueeRect)
        context.saveGState()
        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
        context.fill(frame)
        context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1)
        context.stroke(frame.insetBy(dx: 0.5, dy: 0.5))
        context.restoreGState()
    }
}
