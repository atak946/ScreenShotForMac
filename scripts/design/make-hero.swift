#!/usr/bin/env swift
// Composes the README hero: a window screenshot on a soft gradient card. Not shipped.
//
// Usage (from the repository root, after capture-screenshots.sh):
//   swift scripts/design/make-hero.swift [source name, default "backdrop"]
//
// Reads docs/images/<lang>/<source>.png and writes docs/images/<lang>/hero.png for en and tr.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvasSize = CGSize(width: 2000, height: 1300)
let cornerRadius: CGFloat = 56
let windowWidthRatio: CGFloat = 0.84

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

func drawBackground(_ ctx: CGContext, in rect: CGRect) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    ctx.clip()
    let base = CGGradient(
        colorsSpace: space,
        colors: [rgb(0x2E2385), rgb(0x5B34D6), rgb(0xA43FCF), rgb(0xEE6A9C)] as CFArray,
        locations: [0, 0.4, 0.75, 1]
    )!
    ctx.drawLinearGradient(
        base, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: []
    )
    // Two soft light blooms for depth.
    let bloom = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    let topLeft = CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY - rect.height * 0.1)
    ctx.drawRadialGradient(bloom, startCenter: topLeft, startRadius: 0, endCenter: topLeft, endRadius: rect.width * 0.45, options: [])
    let warm = CGGradient(colorsSpace: space, colors: [rgb(0xFFC48A, 0.3), rgb(0xFFC48A, 0)] as CFArray, locations: [0, 1])!
    let bottomRight = CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.1)
    ctx.drawRadialGradient(warm, startCenter: bottomRight, startRadius: 0, endCenter: bottomRight, endRadius: rect.width * 0.4, options: [])
}

func compose(window: CGImage) -> CGImage {
    let ctx = CGContext(
        data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    let bounds = CGRect(origin: .zero, size: canvasSize)
    ctx.saveGState()
    drawBackground(ctx, in: bounds)
    ctx.restoreGState()

    // The screenshot already carries the macOS window shadow, so draw it as is.
    let width = canvasSize.width * windowWidthRatio
    let height = width * CGFloat(window.height) / CGFloat(window.width)
    let frame = CGRect(x: (canvasSize.width - width) / 2, y: (canvasSize.height - height) / 2, width: width, height: height)
    ctx.draw(window, in: frame)
    return ctx.makeImage()!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceName = CommandLine.arguments.dropFirst().first ?? "backdrop"
for language in ["en", "tr"] {
    let folder = root.appendingPathComponent("docs/images/\(language)")
    guard let window = loadImage(folder.appendingPathComponent("\(sourceName).png")) else {
        FileHandle.standardError.write(Data("Missing \(language)/\(sourceName).png\n".utf8))
        exit(1)
    }
    try writePNG(compose(window: window), to: folder.appendingPathComponent("hero.png"))
}

FileHandle.standardOutput.write(Data("Hero images written\n".utf8))
