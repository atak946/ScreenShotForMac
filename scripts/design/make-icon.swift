#!/usr/bin/env swift
// Renders the app icon with CoreGraphics. Not shipped with the app.
//
// Usage (from the repository root):
//   swift scripts/design/make-icon.swift
//
// Writes App/Resources/Assets.xcassets/AppIcon.appiconset/*.png (+ Contents.json)
// and docs/images/icon.png (256 px).

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Geometry (Apple macOS icon grid on a 1024 canvas)

let canvas: CGFloat = 1024
let bodyInset: CGFloat = 100 // 824 pt body, ~100 pt margin
let cornerRadiusRatio: CGFloat = 0.225

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Rounded body with the macOS template corner radius (22.5% of the body side).
func squircle(in rect: CGRect) -> CGPath {
    let radius = rect.width * cornerRadiusRatio
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: - Drawing

func drawBody(_ ctx: CGContext, body: CGRect) {
    let shape = squircle(in: body)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Soft drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x0B0820, 0.45))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(0x2A1A6E))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // Diagonal base gradient: deep indigo -> violet -> pink.
    let base = CGGradient(
        colorsSpace: space,
        colors: [rgb(0x3B2BB8), rgb(0x6D35E8), rgb(0xB23FD6), rgb(0xF2508F)] as CFArray,
        locations: [0, 0.38, 0.72, 1]
    )!
    ctx.drawLinearGradient(
        base,
        start: CGPoint(x: body.minX, y: body.maxY),
        end: CGPoint(x: body.maxX, y: body.minY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Pink bloom in the lower right and a cool sheen at the top.
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFF8FB8, 0.35), rgb(0xFF8FB8, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: body.maxX, y: body.minY), startRadius: 0,
        endCenter: CGPoint(x: body.maxX, y: body.minY), endRadius: body.width * 0.55,
        options: []
    )
    let sheen = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.12), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        sheen,
        start: CGPoint(x: body.midX, y: body.maxY),
        end: CGPoint(x: body.midX, y: body.midY + body.height * 0.05),
        options: []
    )
    ctx.restoreGState()

    // Fine inner rim for definition on light backgrounds.
    ctx.saveGState()
    ctx.addPath(squircle(in: body.insetBy(dx: 1.5, dy: 1.5)))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.18))
    ctx.setLineWidth(3)
    ctx.strokePath()
    ctx.restoreGState()
}

func drawMark(_ ctx: CGContext, body: CGRect) {
    let side = body.width * 0.54
    let frame = CGRect(x: body.midX - side / 2, y: body.midY - side / 2, width: side, height: side)
    let arm = side * 0.3
    let lineWidth = body.width * 0.066
    let corner = lineWidth * 1.4

    let corners = CGMutablePath()
    // Each corner: arm along x, rounded elbow, arm along y.
    let specs: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: frame.minX, y: frame.maxY), 1, -1),
        (CGPoint(x: frame.maxX, y: frame.maxY), -1, -1),
        (CGPoint(x: frame.minX, y: frame.minY), 1, 1),
        (CGPoint(x: frame.maxX, y: frame.minY), -1, 1),
    ]
    for (origin, sx, sy) in specs {
        corners.move(to: CGPoint(x: origin.x + sx * arm, y: origin.y))
        corners.addArc(
            tangent1End: origin,
            tangent2End: CGPoint(x: origin.x, y: origin.y + sy * arm),
            radius: corner
        )
        corners.addLine(to: CGPoint(x: origin.x, y: origin.y + sy * arm))
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: rgb(0x1A0B4A, 0.35))
    ctx.addPath(corners)
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Capture lens: a ring with a solid center dot.
    let ringRadius = side * 0.2
    let center = CGPoint(x: frame.midX, y: frame.midY)
    ctx.addEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.92))
    ctx.setLineWidth(lineWidth * 0.62)
    ctx.strokePath()

    let dotRadius = side * 0.085
    ctx.addEllipse(in: CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    // Tiny glint on the lens dot.
    let glint = dotRadius * 0.32
    ctx.addEllipse(in: CGRect(
        x: center.x + dotRadius * 0.25 - glint, y: center.y + dotRadius * 0.25 - glint,
        width: glint * 2, height: glint * 2
    ))
    ctx.setFillColor(rgb(0xFFD6EC, 0.9))
    ctx.fillPath()
}

func renderIcon(pixels: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    let scale = CGFloat(pixels) / canvas
    ctx.scaleBy(x: scale, y: scale)
    let body = CGRect(x: 0, y: 0, width: canvas, height: canvas).insetBy(dx: bodyInset, dy: bodyInset)
        .offsetBy(dx: 0, dy: 8) // leave a little more room for the shadow below
    drawBody(ctx, body: body)
    drawMark(ctx, body: body)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

// MARK: - Output

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("App/Resources/Assets.xcassets")
let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try writePNG(renderIcon(pixels: pixels), to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(factor)x", "size": "\(points)x\(points)", "filename": name])
    }
}

let info = ["author": "xcode", "version": 1] as [String: Any]
let iconContents = try JSONSerialization.data(
    withJSONObject: ["images": images, "info": info],
    options: [.prettyPrinted, .sortedKeys]
)
try iconContents.write(to: iconSet.appendingPathComponent("Contents.json"))
let catalogContents = try JSONSerialization.data(withJSONObject: ["info": info], options: [.prettyPrinted, .sortedKeys])
try catalogContents.write(to: catalog.appendingPathComponent("Contents.json"))

try writePNG(renderIcon(pixels: 256), to: root.appendingPathComponent("docs/images/icon.png"))
try writePNG(renderIcon(pixels: 1024), to: root.appendingPathComponent("scripts/design/icon-1024.png"))
FileHandle.standardOutput.write(Data("Icon written to \(iconSet.path)\n".utf8))
