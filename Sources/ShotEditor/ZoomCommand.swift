import CoreGraphics

enum ZoomCommand: Equatable, Sendable {
    case zoomIn, zoomOut, fit, actualSize
    case set(CGFloat)
}
