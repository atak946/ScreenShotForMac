import AppKit
import ShotCore

/// Canvas backdrop: neutral color with a subtle dot grid, soft image shadow and hairline.
extension CanvasView {
    private static let dotSpacing: CGFloat = 16
    private static let dotDiameter: CGFloat = 1.5
    private static let checkerTile: CGFloat = 8

    func drawBackground(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            DS.Palette.canvas.setFill()
            dirtyRect.fill()
            Self.dotPattern(dark: isDarkAppearance).setFill()
            dirtyRect.fill()
        }
    }

    /// Shadowed backing under the image: checkerboard only when the canvas is transparent.
    func drawImageBacking(_ frame: CGRect, transparent: Bool, in context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 24, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        (transparent ? Self.checkerboard : NSColor.white).setFill()
        frame.fill()
        context.restoreGState()
    }

    func drawHairline(around frame: CGRect, in context: CGContext) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            context.saveGState()
            context.setStrokeColor(DS.Palette.surfaceStroke.cgColor)
            context.setLineWidth(1)
            context.stroke(frame.insetBy(dx: -0.5, dy: -0.5))
            context.restoreGState()
        }
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static let lightDots = makeDotPattern(color: NSColor.black.withAlphaComponent(0.09))
    private static let darkDots = makeDotPattern(color: NSColor.white.withAlphaComponent(0.07))

    private static func dotPattern(dark: Bool) -> NSColor { dark ? darkDots : lightDots }

    private static func makeDotPattern(color: NSColor) -> NSColor {
        let spacing = dotSpacing
        let image = NSImage(size: CGSize(width: spacing, height: spacing), flipped: false) { _ in
            color.setFill()
            let origin = (spacing - dotDiameter) / 2
            NSBezierPath(ovalIn: CGRect(x: origin, y: origin, width: dotDiameter, height: dotDiameter)).fill()
            return true
        }
        return NSColor(patternImage: image)
    }

    /// Pattern shown behind transparent canvas areas.
    private static let checkerboard: NSColor = {
        let tile = checkerTile
        let image = NSImage(size: CGSize(width: tile * 2, height: tile * 2), flipped: false) { rect in
            NSColor(white: 0.94, alpha: 1).setFill()
            rect.fill()
            NSColor(white: 0.84, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: tile, height: tile).fill()
            CGRect(x: tile, y: tile, width: tile, height: tile).fill()
            return true
        }
        return NSColor(patternImage: image)
    }()
}
