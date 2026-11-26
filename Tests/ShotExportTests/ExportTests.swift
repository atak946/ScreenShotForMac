import CoreGraphics
import Foundation
import ImageIO
import ShotCore
@testable import ShotExport
import ShotTestSupport
import Testing

@Suite("FilenameTemplate")
struct FilenameTemplateTests {
    private let template = FilenameTemplate()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return try #require(Calendar.current.date(from: components))
    }

    @Test("All tokens are replaced")
    func tokens() throws {
        let when = try date(2024, 3, 5, 14, 7, 9)
        let context = FilenameContext(date: when, appName: "Safari")
        let rendered = template.render(
            template: "{app} {date} at {time} #{counter} {timestamp}", context: context, counter: 7
        )
        #expect(rendered == "Safari 2024-03-05 at 14.07.09 #7 \(Int(when.timeIntervalSince1970))")
    }

    @Test("Default template")
    func defaultTemplate() throws {
        let context = try FilenameContext(date: date(2025, 12, 31, 23, 59, 58))
        #expect(template.render(template: "Screenshot {date} at {time}", context: context, counter: 1)
            == "Screenshot 2025-12-31 at 23.59.58")
    }

    @Test(
        "Sanitization",
        arguments: [
            ("a/b:c\\d", "a-b-c-d"),
            ("  spaced   out  ", "spaced out"),
            (".hidden", "hidden"),
            ("line\nbreak", "line-break"),
            ("/leading", "leading"),
            ("name.", "name"),
            ("", "Screenshot"),
            ("...", "Screenshot"),
            ("Ekran Görüntüsü", "Ekran Görüntüsü"),
        ]
    )
    func sanitize(input: String, expected: String) {
        #expect(FilenameTemplate.sanitize(input) == expected)
    }

    @Test("Missing app name and empty results fall back")
    func fallback() {
        #expect(template.render(template: "{app}", context: FilenameContext(appName: nil), counter: 1) == "Screenshot")
        #expect(template.render(template: "{app}-{counter}", context: FilenameContext(appName: nil), counter: 3) == "3")
    }

    @Test("Names are capped at 200 characters")
    func maxLength() {
        let long = String(repeating: "x", count: 300)
        #expect(FilenameTemplate.sanitize(long).count == 200)
    }

    @Test("Counter increments and persists per defaults suite")
    func counter() throws {
        let suite = "ShotExportTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(FilenameTemplate.nextCounter(defaults: defaults) == 1)
        #expect(FilenameTemplate.nextCounter(defaults: defaults) == 2)
        #expect(FilenameTemplate.nextCounter(defaults: defaults) == 3)
        #expect(defaults.integer(forKey: FilenameTemplate.counterKey) == 3)
        #expect(FilenameTemplate.usesCounter("Shot {counter}"))
        #expect(!FilenameTemplate.usesCounter("Shot {date}"))
    }
}

@Suite("SaveLocation.uniqueURL")
struct UniqueURLTests {
    @Test("Appends (2), (3)… for existing files")
    func uniqueNames() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ShotExportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = SaveLocation.uniqueURL(in: folder, baseName: "Shot", fileExtension: "png")
        #expect(first.lastPathComponent == "Shot.png")
        try Data().write(to: first)

        let second = SaveLocation.uniqueURL(in: folder, baseName: "Shot", fileExtension: "png")
        #expect(second.lastPathComponent == "Shot (2).png")
        try Data().write(to: second)

        #expect(SaveLocation.uniqueURL(in: folder, baseName: "Shot", fileExtension: "png").lastPathComponent == "Shot (3).png")
        #expect(SaveLocation.uniqueURL(in: folder, baseName: "Shot", fileExtension: "jpg").lastPathComponent == "Shot.jpg")
    }
}

@Suite("ImageScaler")
struct ImageScalerTests {
    @Test(
        "Aspect fitting",
        arguments: [
            (CGSize(width: 200, height: 100), CGFloat(100), CGFloat(1000), CGSize(width: 100, height: 50)),
            (CGSize(width: 100, height: 400), CGFloat(100), CGFloat(200), CGSize(width: 50, height: 200)),
            (CGSize(width: 0, height: 100), CGFloat(100), CGFloat(200), CGSize(width: 100, height: 60)),
        ]
    )
    func fitting(size: CGSize, width: CGFloat, maxHeight: CGFloat, expected: CGSize) {
        #expect(ImageScaler.fitting(size, width: width, maxHeight: maxHeight) == expected)
    }

    @Test("Downscale halves Retina images and reports 1x")
    func downscale() throws {
        let image = try #require(TestImages.solid(width: 200, height: 100, color: .red))
        let scaled = ImageScaler.prepare(image, scale: 2, downscale: true)
        #expect(scaled.image.width == 100)
        #expect(scaled.image.height == 50)
        #expect(scaled.scale == 1)

        let untouched = ImageScaler.prepare(image, scale: 2, downscale: false)
        #expect(untouched.image === image)
        #expect(untouched.scale == 2)

        let invalidScale = ImageScaler.prepare(image, scale: 0, downscale: true)
        #expect(invalidScale.image === image)
        #expect(invalidScale.scale == 1)
    }

    @Test("Resize keeps the color content")
    func resize() throws {
        let image = try #require(TestImages.solid(width: 10, height: 10, color: .blue))
        let resized = try #require(ImageScaler.resize(image, width: 3, height: 7))
        #expect(resized.width == 3)
        #expect(resized.height == 7)
        let pixel = try #require(TestImages.pixel(of: resized, x: 1, y: 3))
        #expect(pixel.distance(to: .blue) <= 2)
    }
}

@Suite("ImageEncoder")
struct ImageEncoderTests {
    @Test("PNG embeds the DPI for the backing scale")
    func pngDPI() throws {
        let image = try #require(TestImages.solid(width: 20, height: 10, color: .green))
        let data = try ImageEncoder.pngData(for: image, scale: 2)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyDPIWidth] as? Double) == 144)
        #expect((properties[kCGImagePropertyPixelWidth] as? Int) == 20)
    }

    @Test("Every format encodes and maps to its UTType", arguments: ImageFormat.allCases)
    func formats(format: ImageFormat) throws {
        let image = try #require(TestImages.solid(width: 16, height: 16, color: .red))
        let data = try ImageEncoder.data(for: image, format: format, quality: 0.8, scale: 1)
        #expect(!data.isEmpty)
        #expect(ImageEncoder.utType(for: format).preferredFilenameExtension.map { [format.fileExtension, "jpeg"].contains($0) } == true)
    }
}
