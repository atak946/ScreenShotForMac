import CoreGraphics
import Foundation
import ShotCore
@testable import ShotEditor
import ShotTestSupport
import Testing

@MainActor
private func makeViewModel(_ annotations: [Annotation] = []) throws -> EditorViewModel {
    try EditorViewModel(document: makeDocument().adding(annotations)) { _, _ in }
}

@MainActor
@Suite("EditorViewModel", .serialized)
struct EditorViewModelTests {
    private let first = rectangle(CGRect(x: 0, y: 0, width: 10, height: 10))
    private let second = rectangle(CGRect(x: 20, y: 0, width: 10, height: 10))
    private let third = rectangle(CGRect(x: 40, y: 0, width: 10, height: 10))

    /// Runs `action` as its own undo group, like a separate user event in the app.
    /// (With `groupsByEvent`, registrations without a run-loop turn in between share one group.)
    private func asSeparateEvent(_ model: EditorViewModel, _ action: () -> Void) {
        model.undoManager.beginUndoGrouping()
        action()
        model.undoManager.endUndoGrouping()
    }

    @Test("Apply, undo and redo")
    func undoRedo() throws {
        let model = try makeViewModel()
        model.undoManager.groupsByEvent = false
        #expect(!model.canUndo)
        asSeparateEvent(model) { model.apply("Add") { $0.adding(first) } }
        asSeparateEvent(model) { model.apply("Add") { $0.adding(second) } }
        #expect(model.document.annotations.count == 2)
        #expect(model.canUndo)

        model.undo()
        #expect(model.document.annotations.map(\.id) == [first.id])
        #expect(model.canRedo)
        model.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.canUndo)

        model.redo()
        model.redo()
        #expect(model.document.annotations.map(\.id) == [first.id, second.id])
        #expect(!model.canRedo)
    }

    @Test("No-op changes do not create undo entries")
    func noOpCommit() throws {
        let model = try makeViewModel()
        model.apply("Nothing") { $0 }
        #expect(!model.canUndo)
    }

    @Test("Deleting a multi-selection is undoable and prunes the selection")
    func multiDelete() throws {
        let model = try makeViewModel([first, second, third])
        model.selectedIDs = [first.id, third.id]
        #expect(model.selectedID == nil, "several selected means no single selection")
        model.deleteSelected()
        #expect(model.document.annotations.map(\.id) == [second.id])
        #expect(model.selectedIDs.isEmpty)
        model.undo()
        #expect(model.document.annotations.map(\.id) == [first.id, second.id, third.id])

        model.selectedIDs = [first.id]
        model.redo()
        #expect(model.selectedIDs.isEmpty, "redo removes the deleted ids from the selection")
    }

    @Test("Nudging moves every selected annotation")
    func nudge() throws {
        let model = try makeViewModel([first, second, third])
        model.selectedIDs = [first.id, second.id]
        model.nudgeSelected(by: CGPoint(x: 1, y: 2))
        #expect(model.document.annotation(id: first.id)?.start == CGPoint(x: 1, y: 2))
        #expect(model.document.annotation(id: second.id)?.start == CGPoint(x: 21, y: 2))
        #expect(model.document.annotation(id: third.id)?.start == CGPoint(x: 40, y: 0))
        model.undo()
        #expect(model.document.annotation(id: first.id)?.start == .zero)
    }

    @Test("Z-order changes keep relative order")
    func reorder() throws {
        let model = try makeViewModel([first, second, third])
        model.bringToFront(ids: [first.id, second.id])
        #expect(model.document.annotations.map(\.id) == [third.id, first.id, second.id])
        model.sendToBack(ids: [second.id])
        #expect(model.document.annotations.map(\.id) == [second.id, third.id, first.id])
    }

    @Test("Duplicate offsets copies, selects them and renumbers counters")
    func duplicate() throws {
        let counter = Annotation(kind: .counter, start: .zero, number: 1, style: .default)
        let model = try makeViewModel([first, counter])
        model.duplicate(ids: [first.id, counter.id])
        #expect(model.document.annotations.count == 4)
        let copies = model.selectedAnnotations
        #expect(copies.count == 2)
        #expect(!model.selectedIDs.contains(first.id))
        #expect(copies.first?.start == CGPoint(x: 16, y: 16))
        #expect(copies.last?.number == 2)
    }

    @Test("Recolor skips kinds without a color")
    func recolor() throws {
        let blur = Annotation(kind: .blur, start: .zero, end: CGPoint(x: 5, y: 5), style: .default)
        let model = try makeViewModel([first, blur])
        model.recolor(ids: [first.id, blur.id], to: .blue)
        #expect(model.document.annotation(id: first.id)?.style.color == .blue)
        #expect(model.document.annotation(id: blur.id)?.style.color == AnnotationStyle.default.color)
    }

    @Test("Select all leaves crop mode")
    func selectAll() throws {
        let model = try makeViewModel([first, second])
        model.selectTool(.crop)
        model.selectAll()
        #expect(model.tool == .select)
        #expect(model.selectedIDs == [first.id, second.id])
    }

    @Test("Crop apply, full-canvas crop and undo")
    func crop() throws {
        let model = try makeViewModel()
        model.selectTool(.crop)
        #expect(model.cropDraft == model.document.outputRect)
        model.cropDraft = CGRect(x: 10, y: 10, width: 40, height: 20)
        model.applyCrop()
        #expect(model.document.cropRect == CGRect(x: 10, y: 10, width: 40, height: 20))
        #expect(model.outputPixelSize == CGSize(width: 80, height: 40))
        #expect(model.tool == .select)
        model.undo()
        #expect(model.document.cropRect == nil)

        model.selectTool(.crop)
        model.cropDraft = model.document.canvasRect
        model.applyCrop()
        #expect(model.document.cropRect == nil, "a crop covering the whole canvas is no crop")

        model.selectTool(.crop)
        model.cropDraft = CGRect(x: 0, y: 0, width: 2, height: 2)
        model.applyCrop()
        #expect(model.document.cropRect == nil, "tiny crops are cancelled")
    }

    @Test("Aspect-locked crop drafts fit the canvas")
    func cropAspect() throws {
        let model = try makeViewModel()
        model.selectTool(.crop)
        model.setCropAspect(.square)
        #expect(model.cropDraft == CGRect(x: 25, y: 0, width: 50, height: 50))
        model.setCropAspect(.sixteenNine)
        let draft = try #require(model.cropDraft)
        #expect(abs(draft.width / draft.height - 16.0 / 9.0) < 0.001)
        #expect(model.document.canvasRect.contains(draft))
    }

    @Test("Repeated pastes cascade by 16 pt")
    func pasteOffsets() throws {
        let model = try makeViewModel([first])
        model.selectedIDs = [first.id]
        #expect(model.copySelection())

        model.paste()
        let firstPaste = model.selectedAnnotations
        #expect(firstPaste.count == 1)
        #expect(firstPaste.first?.start == CGPoint(x: 16, y: 16))
        #expect(firstPaste.first?.id != first.id)

        model.paste()
        #expect(model.selectedAnnotations.first?.start == CGPoint(x: 32, y: 32))
        #expect(model.document.annotations.count == 3)

        model.selectedIDs = []
        #expect(!model.copySelection(), "nothing selected, nothing copied")
    }

    @Test("Inserted images are centered and fitted into 60% of the view")
    func insertImage() throws {
        let model = try makeViewModel()
        let image = try #require(TestImages.solid(width: 400, height: 400, color: .green))
        model.insertImage(image, pointSize: CGSize(width: 400, height: 400))
        let inserted = try #require(model.selectedAnnotation)
        #expect(inserted.kind == .image)
        #expect(inserted.rect == CGRect(x: 35, y: 10, width: 30, height: 30))
    }

    @Test("Style changes apply to the single selection")
    func styleChanges() throws {
        let model = try makeViewModel([first])
        model.selectedID = first.id
        model.setLineWidth(8)
        #expect(model.document.annotation(id: first.id)?.style.lineWidth == 8)
        #expect(model.style.lineWidth == 8)
        model.undo()
        #expect(model.document.annotation(id: first.id)?.style.lineWidth == AnnotationStyle.default.lineWidth)
    }
}

@MainActor
@Suite("AnnotationRenderer.flatten")
struct FlattenTests {
    @Test("Full image at native pixel size")
    func fullSize() throws {
        let model = try makeViewModel()
        let image = try #require(model.flatten())
        #expect(image.width == 200)
        #expect(image.height == 100)
        #expect(try #require(TestImages.pixel(of: image, x: 100, y: 50)).distance(to: .red) <= 2)
    }

    @Test("Padding enlarges the output and is filled with the background")
    func padding() throws {
        let model = try makeViewModel()
        model.setPadding(10)
        let image = try #require(model.flatten())
        #expect(image.width == 240)
        #expect(image.height == 140)
        #expect(model.outputPixelSize == CGSize(width: 240, height: 140))
        #expect(try #require(TestImages.pixel(of: image, x: 2, y: 2)).distance(to: .white) <= 2)
        #expect(try #require(TestImages.pixel(of: image, x: 120, y: 70)).distance(to: .red) <= 2)
    }

    @Test("Crop and padding together")
    func cropWithPadding() throws {
        var document = try makeDocument().withPadding(10)
        document = document.withCrop(CGRect(x: -10, y: -10, width: 50, height: 30))
        let renderer = AnnotationRenderer(effects: ImageEffects(scale: 2))
        let image = try #require(renderer.flatten(document))
        #expect(image.width == 100)
        #expect(image.height == 60)
        #expect(try #require(TestImages.pixel(of: image, x: 1, y: 1)).distance(to: .white) <= 2)
        #expect(try #require(TestImages.pixel(of: image, x: 99, y: 59)).distance(to: .red) <= 2)
    }

    @Test("Annotations are drawn into the output")
    func drawsAnnotations() throws {
        let filled = Annotation(
            kind: .rectangle, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 50, y: 50),
            style: AnnotationStyle(
                color: .white, lineWidth: 2, filled: true, fontSize: 12, opacity: 1,
                dashed: false, doubleHeaded: false, cornerRadius: 0
            )
        )
        let renderer = AnnotationRenderer(effects: ImageEffects(scale: 2))
        let image = try #require(try renderer.flatten(makeDocument().adding(filled)))
        #expect(try #require(TestImages.pixel(of: image, x: 50, y: 50)).distance(to: .white) <= 2)
        #expect(try #require(TestImages.pixel(of: image, x: 150, y: 50)).distance(to: .red) <= 2)
    }
}
