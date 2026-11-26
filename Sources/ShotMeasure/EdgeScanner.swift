import Foundation

/// Finds color edges in a pixel buffer for the ruler.
struct EdgeScanner: Sendable {
    static let defaultTolerance = 12
    static let toleranceRange = 0...128

    let buffer: PixelBuffer
    /// Maximum per-channel difference (0...255) still treated as the same color.
    let tolerance: Int

    /// Scans left/right/up/down from `origin` until the color differs from the origin pixel.
    /// Returns the inclusive run of same-colored pixels on both axes through `origin`.
    func span(around origin: PixelPoint) -> PixelRect {
        let reference = buffer.color(x: origin.x, y: origin.y)
        let left = lastMatching(from: origin, dx: -1, dy: 0, reference: reference)
        let right = lastMatching(from: origin, dx: 1, dy: 0, reference: reference)
        let top = lastMatching(from: origin, dx: 0, dy: -1, reference: reference)
        let bottom = lastMatching(from: origin, dx: 0, dy: 1, reference: reference)
        return PixelRect(minX: left.x, minY: top.y, maxX: right.x, maxY: bottom.y)
    }

    /// Shrinks `rect` inward to the bounds of everything that differs from its top-left (background) color.
    /// Returns nil when the whole rect is background.
    func contentBounds(in rect: PixelRect) -> PixelRect? {
        let background = buffer.color(x: rect.minX, y: rect.minY)
        let columns = rect.minX...rect.maxX
        var top = rect.minY
        while top <= rect.maxY, isBackground(row: top, columns: columns, background: background) { top += 1 }
        guard top <= rect.maxY else { return nil }
        var bottom = rect.maxY
        while bottom > top, isBackground(row: bottom, columns: columns, background: background) { bottom -= 1 }
        let rows = top...bottom
        var left = rect.minX
        while left < rect.maxX, isBackground(column: left, rows: rows, background: background) { left += 1 }
        var right = rect.maxX
        while right > left, isBackground(column: right, rows: rows, background: background) { right -= 1 }
        return PixelRect(minX: left, minY: top, maxX: right, maxY: bottom)
    }

    // MARK: Private

    private func matches(x: Int, y: Int, _ reference: RGBColor) -> Bool {
        buffer.color(x: x, y: y).distance(to: reference) <= tolerance
    }

    private func lastMatching(from origin: PixelPoint, dx: Int, dy: Int, reference: RGBColor) -> PixelPoint {
        var x = origin.x
        var y = origin.y
        while buffer.contains(x: x + dx, y: y + dy), matches(x: x + dx, y: y + dy, reference) {
            x += dx
            y += dy
        }
        return PixelPoint(x: x, y: y)
    }

    private func isBackground(row: Int, columns: ClosedRange<Int>, background: RGBColor) -> Bool {
        columns.allSatisfy { matches(x: $0, y: row, background) }
    }

    private func isBackground(column: Int, rows: ClosedRange<Int>, background: RGBColor) -> Bool {
        rows.allSatisfy { matches(x: column, y: $0, background) }
    }
}
