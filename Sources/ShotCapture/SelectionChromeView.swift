import AppKit
import ShotCore

/// Draws the dimmed backdrop with a clear hole for the selection (or hover highlight),
/// the selection border and the round resize handles.
@MainActor
final class SelectionChromeView: NSView {
    var selection: CGRect?
    var highlight: CGRect?
    var showsHandles = false

    private static let outerStrokeColor = NSColor.black.withAlphaComponent(0.35)
    private static let highlightFillAlpha: CGFloat = 0.15
    private static let highlightBorderWidth: CGFloat = 2

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let hole = selection ?? highlight
        let path = NSBezierPath(rect: bounds)
        if let hole {
            path.append(NSBezierPath(rect: hole))
            path.windingRule = .evenOdd
        }
        DS.Palette.overlayDim.setFill()
        path.fill()

        if let selection {
            drawSelectionBorder(selection)
            if showsHandles { drawHandles(for: selection) }
        } else if let highlight {
            drawHighlight(highlight)
        }
    }

    /// 1pt white line with a soft dark halo outside so it reads on light and dark content.
    private func drawSelectionBorder(_ rect: CGRect) {
        let outer = NSBezierPath(rect: rect.insetBy(dx: -1.5, dy: -1.5))
        outer.lineWidth = 1
        Self.outerStrokeColor.setStroke()
        outer.stroke()

        let inner = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        inner.lineWidth = 1
        DS.Palette.selection.setStroke()
        inner.stroke()
    }

    private func drawHighlight(_ rect: CGRect) {
        DS.Palette.accent.withAlphaComponent(Self.highlightFillAlpha).setFill()
        rect.fill(using: .sourceOver)
        let border = NSBezierPath(rect: rect.insetBy(dx: Self.highlightBorderWidth / 2, dy: Self.highlightBorderWidth / 2))
        border.lineWidth = Self.highlightBorderWidth
        DS.Palette.accent.setStroke()
        border.stroke()
    }

    private func drawHandles(for rect: CGRect) {
        let side = SelectionGeometry.handleDrawSize
        let shadow = NSShadow()
        shadow.shadowColor = DS.Palette.selectionShadow
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = CGSize(width: 0, height: -0.5)
        for handle in SelectionHandle.allCases {
            let center = handle.point(in: rect)
            let box = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
            let path = NSBezierPath(ovalIn: box)
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            DS.Palette.selection.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
            path.lineWidth = DS.Size.hairline
            NSColor.black.withAlphaComponent(0.25).setStroke()
            path.stroke()
        }
    }
}
