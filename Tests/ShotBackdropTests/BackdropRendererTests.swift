import CoreGraphics
import Foundation
@testable import ShotBackdrop
import ShotTestSupport
import Testing

private func style(
    aspect: AspectPreset = .auto,
    padding: Double = 10,
    background: BackgroundKind = .solid,
    alignment: BackdropAlignment = .center,
    contentScale: Double = 1
) -> BackdropStyle {
    BackdropStyle(
        background: background, solidColor: RGBAColor(hex: 0x00FF00), padding: padding, cornerRadius: 0,
        shadow: .none, contentScale: contentScale, aspect: aspect, alignment: alignment
    )
}

@Suite("BackdropRenderer")
struct BackdropRendererTests {
    private let imageSize = CGSize(width: 200, height: 100)

    @Test("Auto aspect adds padding scaled to pixels")
    func autoAspect() {
        let layout = BackdropRenderer.layout(imageSize: imageSize, scale: 2, style: style(), fixedSizeFactor: 1)
        #expect(layout.canvasSize == CGSize(width: 240, height: 140))
        #expect(layout.contentRect == CGRect(x: 20, y: 20, width: 200, height: 100))
        #expect(layout.effectiveScale == 2)
    }

    @Test(
        "Ratio presets",
        arguments: [
            (AspectPreset.ratio16x9, 16.0 / 9.0),
            (.ratio4x3, 4.0 / 3.0),
            (.ratio1x1, 1.0),
            (.ratio9x16, 9.0 / 16.0),
        ]
    )
    func ratios(aspect: AspectPreset, ratio: Double) {
        let layout = BackdropRenderer.layout(imageSize: imageSize, scale: 1, style: style(aspect: aspect), fixedSizeFactor: 1)
        let actual = layout.canvasSize.width / layout.canvasSize.height
        #expect(abs(actual - ratio) < 0.01)
        #expect(layout.canvasSize.width >= 220)
        #expect(layout.canvasSize.height >= 120)
        #expect(CGRect(origin: .zero, size: layout.canvasSize).contains(layout.contentRect))
    }

    @Test(
        "Fixed platform sizes",
        arguments: [
            (AspectPreset.twitter, CGSize(width: 1600, height: 900)),
            (.linkedIn, CGSize(width: 1200, height: 627)),
            (.appStore, CGSize(width: 2880, height: 1800))
        ]
    )
    func fixedSizes(aspect: AspectPreset, size: CGSize) {
        let layout = BackdropRenderer.layout(imageSize: imageSize, scale: 1, style: style(aspect: aspect), fixedSizeFactor: 1)
        #expect(layout.canvasSize == size)
        let preview = BackdropRenderer.layout(imageSize: imageSize, scale: 1, style: style(aspect: aspect), fixedSizeFactor: 0.25)
        #expect(preview.canvasSize == CGSize(width: (size.width / 4).rounded(), height: (size.height / 4).rounded()))
    }

    @Test("Content larger than a fixed canvas is shrunk to fit")
    func fitsIntoFixedCanvas() {
        let large = CGSize(width: 4000, height: 1000)
        let layout = BackdropRenderer.layout(imageSize: large, scale: 1, style: style(aspect: .twitter, padding: 50), fixedSizeFactor: 1)
        #expect(layout.contentRect.width == 1500)
        #expect(layout.contentRect.height == 375)
        #expect(layout.effectiveScale < 1)
    }

    @Test("Top and bottom alignment in CG coordinates")
    func alignment() {
        let top = BackdropRenderer.layout(
            imageSize: imageSize, scale: 1, style: style(aspect: .ratio1x1, alignment: .top), fixedSizeFactor: 1
        )
        #expect(top.contentRect.maxY == top.canvasSize.height - 10)
        let bottom = BackdropRenderer.layout(
            imageSize: imageSize, scale: 1, style: style(aspect: .ratio1x1, alignment: .bottom), fixedSizeFactor: 1
        )
        #expect(bottom.contentRect.minY == 10)
    }

    @Test("Content scale insets the screenshot")
    func contentScale() {
        let layout = BackdropRenderer.layout(imageSize: imageSize, scale: 1, style: style(contentScale: 0.5), fixedSizeFactor: 1)
        #expect(layout.contentRect.size == CGSize(width: 100, height: 50))
    }

    @Test("Rendered output matches the layout and draws background and content")
    func render() throws {
        let image = try #require(TestImages.solid(width: 200, height: 100, color: .red))
        let output = try #require(BackdropRenderer.render(image: image, scale: 2, style: style()))
        #expect(output.width == 240)
        #expect(output.height == 140)
        #expect(try #require(TestImages.pixel(of: output, x: 5, y: 5)).distance(to: .green) <= 2)
        #expect(try #require(TestImages.pixel(of: output, x: 120, y: 70)).distance(to: .red) <= 2)

        let clear = try #require(BackdropRenderer.render(image: image, scale: 2, style: style(background: .none)))
        #expect(try #require(TestImages.pixel(of: clear, x: 5, y: 5)).alpha == 0)
    }

    @Test("Style Codable round trip and sanitizing")
    func styleCodable() throws {
        let original = BackdropStyle(
            background: .wallpaper, solidColor: RGBAColor(hex: 0x123456, alpha: 0.5), wallpaperBlur: 12,
            padding: 40, cornerRadius: 8, shadow: .strong, contentScale: 0.75, aspect: .linkedIn, alignment: .bottom
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(BackdropStyle.self, from: data) == original)

        let wild = BackdropStyle(wallpaperBlur: 500, padding: -10, cornerRadius: .infinity, contentScale: 3).sanitized()
        #expect(wild.padding == 0)
        #expect(wild.cornerRadius == 0, "non-finite values fall back to the lower bound")
        #expect(wild.contentScale == 1)
        #expect(wild.wallpaperBlur == 80)
    }

    @Test("Hex color helper")
    func hexColor() {
        let color = RGBAColor(hex: 0xFF8000)
        #expect(color.red == 1)
        #expect(abs(color.green - 128.0 / 255) < 0.0001)
        #expect(color.blue == 0)
    }
}
