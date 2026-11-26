import CoreGraphics
import ShotCore

/// Rotation / flip applied to the base image and all annotation geometry.
enum DocumentTransform: Sendable {
    case rotateLeft, rotateRight, flipHorizontal

    var actionName: String {
        switch self {
        case .rotateLeft: return String(localized: "Rotate Left", bundle: .module)
        case .rotateRight: return String(localized: "Rotate Right", bundle: .module)
        case .flipHorizontal: return String(localized: "Flip Horizontal", bundle: .module)
        }
    }

    func outputSize(for size: CGSize) -> CGSize {
        self == .flipHorizontal ? size : CGSize(width: size.height, height: size.width)
    }

    /// Maps a point of a y-down space of `size` into the transformed space.
    func affine(for size: CGSize) -> CGAffineTransform {
        switch self {
        case .rotateRight: // (x, y) -> (H - y, x)
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: size.height, ty: 0)
        case .rotateLeft: // (x, y) -> (y, W - x)
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: size.width)
        case .flipHorizontal: // (x, y) -> (W - x, y)
            return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: size.width, ty: 0)
        }
    }

    func apply(to image: CGImage) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let output = outputSize(for: size)
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let space,
              let context = CGContext(
                  data: nil, width: Int(output.width), height: Int(output.height), bitsPerComponent: 8,
                  bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            Log.editor.error("Transform failed: could not create bitmap context")
            return nil
        }
        // Switch to a y-down space, apply the mapping, then draw the image upright.
        context.translateBy(x: 0, y: output.height)
        context.scaleBy(x: 1, y: -1)
        context.concatenate(affine(for: size))
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}

@MainActor
extension EditorDocument {
    func transformed(_ transform: DocumentTransform) -> EditorDocument? {
        guard let image = transform.apply(to: baseImage) else { return nil }
        let matrix = transform.affine(for: bounds.size)
        let mapped = annotations.map { $0.transformed(by: matrix) }
        let crop = cropRect.map { $0.applying(matrix) }
        return withBaseImage(image, annotations: mapped, cropRect: crop)
    }
}

@MainActor
extension Annotation {
    /// Geometry follows the transform; text, counters and images stay upright.
    func transformed(by matrix: CGAffineTransform) -> Annotation {
        var copy = self
        switch kind {
        case .text:
            let frame = TextLayout.textFrame(for: self)
            let center = CGPoint(x: frame.midX, y: frame.midY).applying(matrix)
            copy.start = CGPoint(x: center.x - frame.width / 2, y: center.y - frame.height / 2)
            copy.end = copy.start
        case .image:
            let center = CGPoint(x: rect.midX, y: rect.midY).applying(matrix)
            copy.start = CGPoint(x: center.x - rect.width / 2, y: center.y - rect.height / 2)
            copy.end = CGPoint(x: center.x + rect.width / 2, y: center.y + rect.height / 2)
        default:
            copy.start = start.applying(matrix)
            copy.end = end.applying(matrix)
        }
        copy.points = points.map { $0.applying(matrix) }
        copy.callout = callout.applying(matrix)
        return copy
    }
}
