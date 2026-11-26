#!/usr/bin/env swift
// Renders synthetic demo images used for README screenshots. Not shipped with the app.
// All content is made up; no real products, people or data.
//
// Usage (from the repository root):
//   swift scripts/design/make-demo.swift
//
// Writes scripts/design/demo/{dashboard,code,palette}.png at 144 DPI (Retina).

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Helpers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Draws into a top-left-origin context at 2x and saves a 144 DPI PNG.
func render(width: Int, height: Int, to url: URL, draw: (CGRect) -> Void) throws {
    let scale = 2
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let flipped = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = flipped
    flipped.cgContext.translateBy(x: 0, y: CGFloat(height))
    flipped.cgContext.scaleBy(x: 1, y: -1)
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let image = rep.cgImage,
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    let props: [CFString: Any] = [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

func fill(_ rect: CGRect, _ fillColor: NSColor, radius: CGFloat = 0) {
    fillColor.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func stroke(_ rect: CGRect, _ strokeColor: NSColor, radius: CGFloat = 0, width: CGFloat = 1) {
    strokeColor.setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: width / 2, dy: width / 2), xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

func text(
    _ string: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular,
    color textColor: NSColor, mono: Bool = false
) {
    let font = mono
        ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    (string as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: textColor])
}

func circle(center: CGPoint, radius: CGFloat, _ fillColor: NSColor) {
    fillColor.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

func trafficLights(at origin: CGPoint) {
    for (index, hex) in [UInt32(0xFF5F57), 0xFEBC2E, 0x28C840].enumerated() {
        circle(center: CGPoint(x: origin.x + CGFloat(index) * 20, y: origin.y), radius: 6, color(hex))
    }
}

// MARK: - Dashboard

func drawDashboard(_ bounds: CGRect) {
    fill(bounds, color(0xF6F7FB))
    let sidebar = CGRect(x: 0, y: 0, width: 190, height: bounds.height)
    fill(sidebar, color(0xEEF0F7))
    trafficLights(at: CGPoint(x: 22, y: 22))
    fill(CGRect(x: 20, y: 52, width: 28, height: 28), color(0x6D5DF5), radius: 8)
    text("Orbit", at: CGPoint(x: 58, y: 56), size: 15, weight: .bold, color: color(0x1D1B3A))
    let items = ["Overview", "Reports", "Customers", "Billing", "Settings"]
    for (index, item) in items.enumerated() {
        let y = 104 + CGFloat(index) * 36
        if index == 0 { fill(CGRect(x: 12, y: y - 6, width: 166, height: 30), color(0xFFFFFF), radius: 8) }
        circle(center: CGPoint(x: 32, y: y + 9), radius: 5, index == 0 ? color(0x6D5DF5) : color(0xB6B9CC))
        text(
            item, at: CGPoint(x: 46, y: y), size: 13, weight: index == 0 ? .semibold : .regular,
            color: index == 0 ? color(0x1D1B3A) : color(0x6B6F86)
        )
    }

    let left: CGFloat = 220
    text("Overview", at: CGPoint(x: left, y: 30), size: 24, weight: .bold, color: color(0x1D1B3A))
    text("Last 30 days · demo data", at: CGPoint(x: left, y: 62), size: 12, color: color(0x8A8EA6))
    fill(CGRect(x: bounds.width - 150, y: 32, width: 120, height: 30), color(0x6D5DF5), radius: 8)
    text("Export report", at: CGPoint(x: bounds.width - 133, y: 38), size: 12, weight: .semibold, color: .white)

    let stats: [(String, String, String, UInt32)] = [
        ("Revenue", "$48.2k", "+12.4%", 0x16A34A), ("Active users", "3,914", "+5.1%", 0x16A34A),
        ("Conversion", "4.7%", "−0.3%", 0xDC2626),
    ]
    let cardWidth = (bounds.width - left - 30 - 2 * 16) / 3
    for (index, stat) in stats.enumerated() {
        let card = CGRect(x: left + CGFloat(index) * (cardWidth + 16), y: 96, width: cardWidth, height: 96)
        fill(card, .white, radius: 14)
        stroke(card, color(0xE4E6F0), radius: 14)
        text(stat.0, at: CGPoint(x: card.minX + 18, y: card.minY + 16), size: 12, color: color(0x8A8EA6))
        text(stat.1, at: CGPoint(x: card.minX + 18, y: card.minY + 38), size: 26, weight: .bold, color: color(0x1D1B3A))
        text(stat.2, at: CGPoint(x: card.maxX - 70, y: card.minY + 48), size: 12, weight: .semibold, color: color(stat.3))
    }

    let chart = CGRect(x: left, y: 210, width: bounds.width - left - 30, height: bounds.height - 240)
    fill(chart, .white, radius: 14)
    stroke(chart, color(0xE4E6F0), radius: 14)
    text("Weekly sessions", at: CGPoint(x: chart.minX + 18, y: chart.minY + 16), size: 14, weight: .semibold, color: color(0x1D1B3A))
    drawAreaChart(in: chart.insetBy(dx: 24, dy: 24).offsetBy(dx: 0, dy: 18).insetBy(dx: 0, dy: 10))
}

func drawAreaChart(in plot: CGRect) {
    for line in 0...3 {
        let y = plot.minY + CGFloat(line) * plot.height / 3
        fill(CGRect(x: plot.minX, y: y, width: plot.width, height: 1), color(0xEEF0F6))
    }
    let values: [CGFloat] = [0.32, 0.45, 0.38, 0.56, 0.5, 0.68, 0.62, 0.78, 0.71, 0.86, 0.8, 0.92]
    let points = values.enumerated().map { index, value in
        CGPoint(
            x: plot.minX + CGFloat(index) / CGFloat(values.count - 1) * plot.width,
            y: plot.maxY - value * plot.height
        )
    }
    let area = NSBezierPath()
    area.move(to: CGPoint(x: plot.minX, y: plot.maxY))
    points.forEach { area.line(to: $0) }
    area.line(to: CGPoint(x: plot.maxX, y: plot.maxY))
    area.close()
    NSGradient(starting: color(0x6D5DF5, 0.35), ending: color(0x6D5DF5, 0.02))?.draw(in: area, angle: -90)
    let line = NSBezierPath()
    line.move(to: points[0])
    points.dropFirst().forEach { line.line(to: $0) }
    line.lineWidth = 3
    line.lineJoinStyle = .round
    color(0x6D5DF5).setStroke()
    line.stroke()
    if let last = points.last {
        circle(center: last, radius: 7, .white)
        circle(center: last, radius: 5, color(0x6D5DF5))
    }
}

// MARK: - Code editor

func drawCode(_ bounds: CGRect) {
    fill(bounds, color(0x1B1D2A))
    fill(CGRect(x: 0, y: 0, width: bounds.width, height: 44), color(0x151722))
    trafficLights(at: CGPoint(x: 22, y: 22))
    fill(CGRect(x: 90, y: 8, width: 150, height: 36), color(0x1B1D2A), radius: 6)
    text("Greeting.swift", at: CGPoint(x: 106, y: 17), size: 12, weight: .medium, color: color(0xE6E8F2))
    text("Package.swift", at: CGPoint(x: 262, y: 17), size: 12, color: color(0x7C8099))

    let keyword: UInt32 = 0xF472B6, type: UInt32 = 0x7DD3FC, string: UInt32 = 0xFBBF77
    let plain: UInt32 = 0xE6E8F2, comment: UInt32 = 0x6B7089, function: UInt32 = 0xA78BFA
    let lines: [[(String, UInt32)]] = [
        [("// A tiny demo file for screenshots.", comment)],
        [("import", keyword), (" SwiftUI", plain)],
        [],
        [("struct", keyword), (" Greeting", type), (": ", plain), ("View", type), (" {", plain)],
        [("    let", keyword), (" name: ", plain), ("String", type)],
        [("    @State", keyword), (" private var", keyword), (" count = ", plain), ("0", string)],
        [],
        [("    var", keyword), (" body: ", plain), ("some", keyword), (" View", type), (" {", plain)],
        [("        VStack", type), ("(spacing: ", plain), ("12", string), (") {", plain)],
        [("            Text", type), ("(", plain), ("\"Hello, \\(name)!\"", string), (")", plain)],
        [("                .", plain), ("font", function), ("(.title.bold())", plain)],
        [("            Button", type), ("(", plain), ("\"Tapped \\(count) times\"", string), (") {", plain)],
        [("                count += ", plain), ("1", string)],
        [("            }", plain)],
        [("            .", plain), ("buttonStyle", function), ("(.borderedProminent)", plain)],
        [("        }", plain)],
        [("        .", plain), ("padding", function), ("(", plain), ("24", string), (")", plain)],
        [("    }", plain)],
        [("}", plain)],
    ]
    let lineHeight: CGFloat = 22
    for (index, tokens) in lines.enumerated() {
        let y = 64 + CGFloat(index) * lineHeight
        if index == 9 { fill(CGRect(x: 0, y: y - 3, width: bounds.width, height: lineHeight), color(0x262A3D)) }
        let number = String(index + 1)
        text(number, at: CGPoint(x: 44 - CGFloat(number.count) * 8, y: y), size: 13, color: color(0x4B5068), mono: true)
        var x: CGFloat = 70
        for token in tokens {
            text(token.0, at: CGPoint(x: x, y: y), size: 13, color: color(token.1), mono: true)
            x += (token.0 as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)]).width
        }
    }
    let status = CGRect(x: 0, y: bounds.height - 26, width: bounds.width, height: 26)
    fill(status, color(0x6D5DF5))
    text("main  ·  Swift  ·  Ln 10, Col 32", at: CGPoint(x: 16, y: status.minY + 5), size: 11, weight: .medium, color: .white)
}

// MARK: - Palette card

func drawPalette(_ bounds: CGRect) {
    fill(bounds, color(0xFFFFFF))
    text("Sunset palette", at: CGPoint(x: 32, y: 30), size: 22, weight: .bold, color: color(0x1D1B3A))
    text("Five colors for the demo theme", at: CGPoint(x: 32, y: 62), size: 12, color: color(0x8A8EA6))
    let swatches: [(UInt32, String)] = [
        (0x3B2BB8, "Indigo"), (0x6D35E8, "Violet"), (0xB23FD6, "Orchid"), (0xF2508F, "Rose"), (0xFFB37A, "Peach"),
    ]
    let gap: CGFloat = 14
    let width = (bounds.width - 64 - gap * CGFloat(swatches.count - 1)) / CGFloat(swatches.count)
    for (index, swatch) in swatches.enumerated() {
        let rect = CGRect(x: 32 + CGFloat(index) * (width + gap), y: 100, width: width, height: bounds.height - 190)
        fill(rect, color(swatch.0), radius: 16)
        text(swatch.1, at: CGPoint(x: rect.minX + 4, y: rect.maxY + 14), size: 13, weight: .semibold, color: color(0x1D1B3A))
        text(
            String(format: "#%06X", swatch.0), at: CGPoint(x: rect.minX + 4, y: rect.maxY + 34),
            size: 12, color: color(0x8A8EA6), mono: true
        )
    }
}

// MARK: - Output

let demo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("scripts/design/demo")
try render(width: 900, height: 560, to: demo.appendingPathComponent("dashboard.png"), draw: drawDashboard)
try render(width: 760, height: 530, to: demo.appendingPathComponent("code.png"), draw: drawCode)
try render(width: 620, height: 420, to: demo.appendingPathComponent("palette.png"), draw: drawPalette)
FileHandle.standardOutput.write(Data("Demo images written to \(demo.path)\n".utf8))
