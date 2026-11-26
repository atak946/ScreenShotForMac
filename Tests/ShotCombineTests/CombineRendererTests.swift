import CoreGraphics
@testable import ShotCombine
import ShotTestSupport
import Testing

private func layout(
    _ arrangement: CombineArrangement,
    columns: Int = 2,
    spacing: Double = 10,
    padding: Double = 5,
    alignment: CombineAlignment = .start,
    matchSizes: Bool = false
) -> CombineLayout {
    CombineLayout(
        arrangement: arrangement, columns: columns, spacing: spacing, padding: padding,
        alignment: alignment, matchSizes: matchSizes
    )
}

@Suite("CombineRenderer.plan")
struct CombinePlanTests {
    private let sizes = [CGSize(width: 100, height: 50), CGSize(width: 60, height: 80)]

    @Test("Vertical stack")
    func vertical() {
        let plan = CombineRenderer.plan(sizes: sizes, layout: layout(.vertical), outputScale: 1)
        #expect(plan.canvasSize == CGSize(width: 110, height: 150))
        #expect(plan.frames == [CGRect(x: 5, y: 5, width: 100, height: 50), CGRect(x: 5, y: 65, width: 60, height: 80)])
    }

    @Test("Horizontal row with center alignment")
    func horizontal() {
        let plan = CombineRenderer.plan(sizes: sizes, layout: layout(.horizontal, alignment: .center), outputScale: 1)
        #expect(plan.canvasSize == CGSize(width: 180, height: 90))
        #expect(plan.frames == [CGRect(x: 5, y: 20, width: 100, height: 50), CGRect(x: 115, y: 5, width: 60, height: 80)])
    }

    @Test("Grid wraps rows and sizes columns by their widest item")
    func grid() {
        let four = sizes + [CGSize(width: 40, height: 40), CGSize(width: 120, height: 10)]
        let plan = CombineRenderer.plan(sizes: four, layout: layout(.grid, alignment: .end), outputScale: 1)
        // Columns: max(100, 40) = 100, max(60, 120) = 120. Rows: 80, 40.
        #expect(plan.canvasSize == CGSize(width: 5 + 100 + 10 + 120 + 5, height: 5 + 80 + 10 + 40 + 5))
        #expect(plan.frames[0] == CGRect(x: 5, y: 35, width: 100, height: 50))
        #expect(plan.frames[1] == CGRect(x: 175, y: 5, width: 60, height: 80))
        #expect(plan.frames[2] == CGRect(x: 65, y: 95, width: 40, height: 40))
        #expect(plan.frames[3] == CGRect(x: 115, y: 125, width: 120, height: 10))
    }

    @Test("More columns than images collapses to one row")
    func gridColumnsClamp() {
        let plan = CombineRenderer.plan(sizes: sizes, layout: layout(.grid, columns: 12), outputScale: 1)
        #expect(plan.canvasSize == CombineRenderer.plan(sizes: sizes, layout: layout(.horizontal), outputScale: 1).canvasSize)
    }

    @Test("Output scale multiplies geometry")
    func outputScale() {
        let plan = CombineRenderer.plan(sizes: sizes, layout: layout(.vertical), outputScale: 2)
        #expect(plan.canvasSize == CGSize(width: 220, height: 300))
        #expect(plan.frames.first == CGRect(x: 10, y: 10, width: 200, height: 100))
        #expect(plan.outputScale == 2)
    }

    @Test("Match sizes equalizes widths with a 2x upscale cap")
    func matchSizes() {
        let mixed = [CGSize(width: 300, height: 100), CGSize(width: 100, height: 100), CGSize(width: 200, height: 50)]
        let matched = CombineRenderer.matchedSizes(mixed, layout: layout(.vertical, matchSizes: true))
        #expect(matched == [CGSize(width: 300, height: 100), CGSize(width: 200, height: 200), CGSize(width: 300, height: 75)])
        let byHeight = CombineRenderer.matchedSizes(mixed, layout: layout(.horizontal, matchSizes: true))
        #expect(byHeight == [CGSize(width: 300, height: 100), CGSize(width: 100, height: 100), CGSize(width: 400, height: 100)])
        #expect(CombineRenderer.matchedSizes(mixed, layout: layout(.vertical)) == mixed)
    }

    @Test("Out-of-range layout values are sanitized")
    func sanitized() {
        let raw = CombineLayout(columns: 0, spacing: 999, padding: -5, cornerRadius: 100).sanitized()
        #expect(raw.columns == 1)
        #expect(raw.spacing == 120)
        #expect(raw.padding == 0)
        #expect(raw.cornerRadius == 48)
    }

    @Test("Huge layouts are capped to the max pixel dimension")
    func cap() {
        let plan = CombineRenderer.plan(sizes: [CGSize(width: 10, height: 40000)], layout: layout(.vertical, padding: 0), outputScale: 1)
        #expect(plan.canvasSize.height == CombineRenderer.maxPixelDimension)
        #expect(plan.outputScale < 1)
    }

    @Test("Render produces the planned canvas with images in place")
    func render() throws {
        let red = try #require(TestImages.solid(width: 20, height: 10, color: .red))
        let blue = try #require(TestImages.solid(width: 20, height: 10, color: .blue))
        let images = [CombineImage(image: red, scale: 1), CombineImage(image: blue, scale: 2)]
        let output = try #require(CombineRenderer.render(images: images, layout: layout(.vertical, spacing: 0, padding: 0)))
        // Output scale is the largest input scale (2): red 40x20 px, blue 20x10 px.
        #expect(output.width == 40)
        #expect(output.height == 30)
        #expect(try #require(TestImages.pixel(of: output, x: 2, y: 2)).distance(to: .red) <= 2)
        #expect(try #require(TestImages.pixel(of: output, x: 5, y: 25)).distance(to: .blue) <= 2)
        #expect(try #require(TestImages.pixel(of: output, x: 35, y: 25)).distance(to: .white) <= 2)
        #expect(CombineRenderer.render(images: [], layout: .standard) == nil)
    }
}

@Suite("SplitRenderer")
struct SplitRendererTests {
    @Test("Equal cuts")
    func equalCuts() {
        #expect(SplitRenderer.equalCuts(count: 4) == [0.25, 0.5, 0.75])
        #expect(SplitRenderer.equalCuts(count: 1) == [0.5], "count is clamped to at least 2")
        #expect(SplitRenderer.equalCuts(count: 100).count == 19)
    }

    @Test("Cuts are sorted, de-duplicated and kept off the edges")
    func normalized() {
        #expect(SplitRenderer.normalizedCuts([0.7, 0.3, 0.301, 0, 1, 0.001, 0.5]) == [0.3, 0.5, 0.7])
    }

    @Test("Slice rects for both axes")
    func sliceRects() {
        let size = CGSize(width: 100, height: 300)
        #expect(SplitRenderer.sliceRects(pixelSize: size, axis: .horizontal, cuts: [1.0 / 3, 2.0 / 3]) == [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 0, y: 100, width: 100, height: 100),
            CGRect(x: 0, y: 200, width: 100, height: 100),
        ])
        #expect(SplitRenderer.sliceRects(pixelSize: size, axis: .vertical, cuts: [0.25]) == [
            CGRect(x: 0, y: 0, width: 25, height: 300),
            CGRect(x: 25, y: 0, width: 75, height: 300),
        ])
        #expect(SplitRenderer.sliceRects(pixelSize: size, axis: .vertical, cuts: []) == [CGRect(origin: .zero, size: size)])
    }

    @Test("Slices crop the image in order")
    func slices() throws {
        let image = try #require(TestImages.make(width: 10, height: 20) { _, y in y < 10 ? .red : .green })
        let parts = SplitRenderer.slices(of: image, axis: .horizontal, cuts: [0.5])
        #expect(parts.count == 2)
        #expect(parts.allSatisfy { $0.width == 10 && $0.height == 10 })
        #expect(try TestImages.pixel(of: #require(parts.first), x: 5, y: 5) == .red)
        #expect(try TestImages.pixel(of: #require(parts.last), x: 5, y: 5) == .green)
    }
}
