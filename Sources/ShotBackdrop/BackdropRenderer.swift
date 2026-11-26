import CoreGraphics
import Foundation

/// Geometry of a composed backdrop, in output pixels (CG bottom-left origin).
struct BackdropLayout: Equatable {
    let canvasSize: CGSize
    let contentRect: CGRect
    /// Pixels per point after any fit-to-canvas downscale (used for radius / shadow).
    let effectiveScale: CGFloat
}

/// Pure rendering of a screenshot onto a backdrop. No UI, no I/O.
public enum BackdropRenderer {
    /// Hard cap per side to keep memory bounded.
    static let maxCanvasSide: CGFloat = 16384

    /// Renders at full pixel resolution.
    /// - Parameters:
    ///   - image: Screenshot pixels.
    ///   - scale: Pixels per point of `image` (2 on Retina).
    ///   - style: Composition style.
    ///   - wallpaper: Pre-blurred wallpaper, used when `style.background == .wallpaper`.
    ///   - fixedSizeFactor: Multiplier for platform presets' fixed pixel sizes (preview uses < 1).
    public static func render(
        image: CGImage,
        scale: CGFloat,
        style: BackdropStyle,
        wallpaper: CGImage? = nil,
        fixedSizeFactor: CGFloat = 1
    ) -> CGImage? {
        let style = style.sanitized()
        let layout = layout(
            imageSize: CGSize(width: image.width, height: image.height),
            scale: max(scale, 0.01),
            style: style,
            fixedSizeFactor: fixedSizeFactor
        )
        guard let context = makeContext(size: layout.canvasSize) else { return nil }
        let canvas = CGRect(origin: .zero, size: layout.canvasSize)
        drawBackground(in: context, rect: canvas, style: style, wallpaper: wallpaper)
        drawContent(image, in: context, layout: layout, style: style)
        return context.makeImage()
    }

    // MARK: Layout

    static func layout(imageSize: CGSize, scale: CGFloat, style: BackdropStyle, fixedSizeFactor: CGFloat) -> BackdropLayout {
        let contentScale = CGFloat(style.contentScale)
        let content = CGSize(width: imageSize.width * contentScale, height: imageSize.height * contentScale)
        let pad = CGFloat(style.padding) * scale
        let natural = CGSize(width: content.width + pad * 2, height: content.height + pad * 2)
        let canvas = clampCanvas(canvasSize(natural: natural, style: style, fixedSizeFactor: fixedSizeFactor))

        let available = CGSize(width: max(canvas.width - pad * 2, 1), height: max(canvas.height - pad * 2, 1))
        let fit = min(1, available.width / max(content.width, 1), available.height / max(content.height, 1))
        let size = CGSize(width: (content.width * fit).rounded(), height: (content.height * fit).rounded())
        let x = ((canvas.width - size.width) / 2).rounded()
        let y: CGFloat = switch style.alignment {
        case .center: ((canvas.height - size.height) / 2).rounded()
        case .top: max(0, canvas.height - pad - size.height).rounded()
        case .bottom: min(pad, canvas.height - size.height).rounded()
        }
        return BackdropLayout(
            canvasSize: canvas,
            contentRect: CGRect(origin: CGPoint(x: x, y: y), size: size),
            effectiveScale: scale * fit * contentScale
        )
    }

    private static func canvasSize(natural: CGSize, style: BackdropStyle, fixedSizeFactor: CGFloat) -> CGSize {
        if let fixed = style.aspect.fixedPixelSize {
            return CGSize(width: fixed.width * fixedSizeFactor, height: fixed.height * fixedSizeFactor)
        }
        guard let ratio = style.aspect.ratio.map({ CGFloat($0) }) else { return natural }
        if natural.width / max(natural.height, 1) > ratio {
            return CGSize(width: natural.width, height: natural.width / ratio)
        }
        return CGSize(width: natural.height * ratio, height: natural.height)
    }

    private static func clampCanvas(_ size: CGSize) -> CGSize {
        let longest = max(size.width, size.height)
        let factor = longest > maxCanvasSide ? maxCanvasSide / longest : 1
        return CGSize(
            width: max(1, (size.width * factor).rounded()),
            height: max(1, (size.height * factor).rounded())
        )
    }

    // MARK: Drawing

    private static func makeContext(size: CGSize) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .high
        return context
    }

    private static func drawBackground(in context: CGContext, rect: CGRect, style: BackdropStyle, wallpaper: CGImage?) {
        switch style.background {
        case .none:
            context.clear(rect)
        case .solid:
            context.setFillColor(style.solidColor.cgColor)
            context.fill(rect)
        case .gradient:
            drawGradient(style.gradient, in: context, rect: rect)
        case .wallpaper:
            if let wallpaper {
                context.draw(wallpaper, in: aspectFill(CGSize(width: wallpaper.width, height: wallpaper.height), in: rect))
            } else {
                drawGradient(GradientPresets.all[0].spec, in: context, rect: rect)
            }
        }
    }

    private static func drawGradient(_ spec: GradientSpec, in context: CGContext, rect: CGRect) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(
                  colorsSpace: space,
                  colors: [spec.start.cgColor, spec.end.cgColor] as CFArray,
                  locations: [0, 1]
              )
        else { return }
        let radians = spec.angle * .pi / 180
        let direction = CGVector(dx: sin(radians), dy: cos(radians))
        let half = (abs(rect.width * direction.dx) + abs(rect.height * direction.dy)) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = CGPoint(x: center.x - direction.dx * half, y: center.y - direction.dy * half)
        let end = CGPoint(x: center.x + direction.dx * half, y: center.y + direction.dy * half)
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func drawContent(_ image: CGImage, in context: CGContext, layout: BackdropLayout, style: BackdropStyle) {
        let rect = layout.contentRect
        let radius = min(CGFloat(style.cornerRadius) * layout.effectiveScale, min(rect.width, rect.height) / 2)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        context.saveGState()
        if style.shadow != .none {
            let shadowScale = layout.effectiveScale
            context.setShadow(
                offset: CGSize(width: 0, height: -CGFloat(style.shadow.offsetY) * shadowScale),
                blur: CGFloat(style.shadow.blur) * shadowScale,
                color: CGColor(gray: 0, alpha: style.shadow.opacity)
            )
        }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.addPath(path)
        context.clip()
        context.draw(image, in: rect)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        let factor = max(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
        let fitted = CGSize(width: size.width * factor, height: size.height * factor)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
