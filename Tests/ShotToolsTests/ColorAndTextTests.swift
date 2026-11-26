import CoreGraphics
import ShotCore
@testable import ShotTools
import Testing

@Suite("ColorFormatter")
struct ColorFormatterTests {
    private let orange = PickedColor(red: 1, green: 0.5, blue: 0)
    private let translucent = PickedColor(red: 1, green: 0.5, blue: 0, alpha: 0.5)

    @Test("Opaque color in every format")
    func opaqueFormats() {
        #expect(ColorFormatter.string(for: orange, format: .hex) == "#FF8000")
        #expect(ColorFormatter.string(for: orange, format: .rgb) == "rgb(255, 128, 0)")
        #expect(ColorFormatter.string(for: orange, format: .hsl) == "hsl(30, 100%, 50%)")
        #expect(ColorFormatter.string(for: orange, format: .swiftUI) == "Color(red: 1.000, green: 0.500, blue: 0.000)")
        #expect(
            ColorFormatter.string(for: orange, format: .nsColor)
                == "NSColor(srgbRed: 1.000, green: 0.500, blue: 0.000, alpha: 1)"
        )
    }

    @Test("Alpha below 1 is included where the format supports it")
    func alphaFormats() {
        #expect(ColorFormatter.string(for: translucent, format: .hex) == "#FF800080")
        #expect(ColorFormatter.string(for: translucent, format: .rgb) == "rgb(255, 128, 0)")
        #expect(
            ColorFormatter.string(for: translucent, format: .swiftUI)
                == "Color(red: 1.000, green: 0.500, blue: 0.000, opacity: 0.500)"
        )
        #expect(
            ColorFormatter.string(for: translucent, format: .nsColor)
                == "NSColor(srgbRed: 1.000, green: 0.500, blue: 0.000, alpha: 0.500)"
        )
    }

    @Test(
        "HSL hue, saturation and lightness",
        arguments: [
            (PickedColor(red: 0.5, green: 0.5, blue: 0.5), "hsl(0, 0%, 50%)"),
            (PickedColor(red: 0, green: 0, blue: 1), "hsl(240, 100%, 50%)"),
            (PickedColor(red: 0, green: 1, blue: 0), "hsl(120, 100%, 50%)"),
            (PickedColor(red: 1, green: 0, blue: 0.5), "hsl(330, 100%, 50%)"),
            (PickedColor(red: 1, green: 1, blue: 1), "hsl(0, 0%, 100%)"),
            (PickedColor(red: 0, green: 0, blue: 0), "hsl(0, 0%, 0%)"),
        ]
    )
    func hsl(color: PickedColor, expected: String) {
        #expect(ColorFormatter.string(for: color, format: .hsl) == expected)
    }

    @Test("Out-of-range components are clamped")
    func clamping() {
        let color = PickedColor(red: 1.5, green: -0.2, blue: 0.25)
        #expect(ColorFormatter.string(for: color, format: .hex) == "#FF0040")
        #expect(ColorFormatter.string(for: color, format: .rgb) == "rgb(255, 0, 64)")
    }
}

@Suite("TextPostProcessing")
struct TextPostProcessingTests {
    @Test(
        "Joins OCR lines into paragraphs",
        arguments: [
            ("Hello\nworld", "Hello world"),
            ("exam-\nple text", "example text"),
            ("well-\nKnown", "well- Known"),
            ("page 1-\n2", "page 1- 2"),
            ("first\n\nsecond", "first\n\nsecond"),
            ("  a  \n   b ", "a b"),
            ("\n\none\ntwo\n\n\nthree\n", "one two\n\nthree"),
            ("", ""),
        ]
    )
    func joins(input: String, expected: String) {
        #expect(TextPostProcessing.joinedIntoParagraph(input) == expected)
    }
}

@Suite("OCREngine helpers")
struct OCREngineTests {
    @Test("Fragments are ordered top-to-bottom and left-to-right")
    func layoutOrdersLines() {
        let fragments = [
            OCREngine.Fragment(text: "Second", box: CGRect(x: 0.1, y: 0.5, width: 0.3, height: 0.1)),
            OCREngine.Fragment(text: "World", box: CGRect(x: 0.5, y: 0.81, width: 0.2, height: 0.1)),
            OCREngine.Fragment(text: "Hello", box: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.1)),
        ]
        #expect(OCREngine.layout(fragments) == "Hello World\nSecond")
    }

    @Test("Barely overlapping boxes are separate lines")
    func layoutSeparatesLines() {
        let fragments = [
            OCREngine.Fragment(text: "A", box: CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)),
            OCREngine.Fragment(text: "B", box: CGRect(x: 0.1, y: 0.42, width: 0.1, height: 0.1)),
        ]
        #expect(OCREngine.layout(fragments) == "A\nB")
        #expect(OCREngine.layout([]).isEmpty)
    }

    @Test("Requested languages resolve to supported codes")
    func resolveLanguages() {
        let supported = ["en-US", "fr-FR", "de-DE", "zh-Hans"]
        #expect(OCREngine.resolveLanguages(["EN-us", "tr-TR", "de", "fr-CA"], supported: supported) == ["en-US", "de-DE", "fr-FR"])
        #expect(OCREngine.resolveLanguages(["en-GB", "en-US"], supported: supported) == ["en-US"])
        #expect(OCREngine.resolveLanguages(["zh"], supported: supported) == ["zh-Hans"])
        #expect(OCREngine.resolveLanguages(["ja-JP"], supported: supported).isEmpty)
    }

    @Test("Normalized boxes map to padded, clamped pixel rects")
    func pixelRect() {
        let size = CGSize(width: 200, height: 100)
        let rect = SensitiveScan.pixelRect(fromNormalized: CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25), imageSize: size)
        #expect(rect == CGRect(x: 48, y: 23, width: 104, height: 29))
        let edge = SensitiveScan.pixelRect(fromNormalized: CGRect(x: 0, y: 0, width: 1, height: 1), imageSize: size)
        #expect(edge == CGRect(origin: .zero, size: size))
    }
}
