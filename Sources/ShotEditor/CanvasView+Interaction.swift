import AppKit

enum CanvasDragState {
    case idle
    case creating(id: UUID, snapshot: EditorDocument)
    case moving(id: UUID, part: MovePart, last: CGPoint, snapshot: EditorDocument)
    case movingGroup(ids: Set<UUID>, last: CGPoint, snapshot: EditorDocument)
    /// Rubber-band selection; `base` is the selection kept when extending with Shift / ⌘.
    case marquee(origin: CGPoint, base: Set<UUID>)
    case resizing(id: UUID, handle: HandleKind, snapshot: EditorDocument)
    case cropNew(origin: CGPoint, previous: CGRect?)
    case cropMoving(last: CGPoint)
    case cropResizing(handle: HandleKind)
    case panning(last: CGPoint)
}

extension CanvasView {
    private static let minimumShapeSize: CGFloat = 3

    func documentPoint(for event: NSEvent) -> CGPoint {
        layout.toDocument(convert(event.locationInWindow, from: nil))
    }

    // MARK: - Mouse down

    override func mouseDown(with event: NSEvent) {
        if textEditor.isEditing {
            textEditor.commit()
            return
        }
        window?.makeFirstResponder(self)
        if isSpacePressed {
            dragState = .panning(last: convert(event.locationInWindow, from: nil))
            NSCursor.closedHand.set()
            return
        }
        let point = documentPoint(for: event)
        let tolerance = layout.documentLength(Self.hitTolerance)

        if viewModel.tool == .crop {
            if event.clickCount == 2 { viewModel.applyCrop()
                return
            }
            beginCropDrag(at: point, tolerance: tolerance)
            return
        }
        let hit = HitTesting.topmost(in: viewModel.document, at: point, tolerance: tolerance)
        if event.clickCount == 2, let hit, hit.kind == .text {
            startTextEditing(existing: hit.id, at: hit.start)
            return
        }
        if beginHandleDrag(at: point, tolerance: tolerance) { return }
        beginToolAction(at: point, hit: hit, modifiers: event.modifierFlags)
    }

    private func beginToolAction(at point: CGPoint, hit: Annotation?, modifiers: NSEvent.ModifierFlags) {
        switch viewModel.tool {
        case .select:
            beginSelectAction(at: point, hit: hit, extending: !modifiers.isDisjoint(with: [.shift, .command]))
        case .text:
            if let hit, hit.kind == .text {
                startTextEditing(existing: hit.id, at: hit.start)
            } else {
                startTextEditing(existing: nil, at: point)
            }
        case .counter:
            let counter = Annotation(
                kind: .counter, start: point, number: viewModel.document.nextCounterNumber,
                style: viewModel.creationStyle(for: .counter)
            )
            viewModel.apply(String(localized: "Add Counter", bundle: .module)) { $0.adding(counter) }
            viewModel.selectedID = counter.id
        case .crop:
            break
        default:
            beginCreating(at: point)
        }
    }

    private func beginCreating(at point: CGPoint) {
        guard let kind = viewModel.tool.annotationKind else { return }
        let snapshot = viewModel.document
        let annotation = Annotation(
            kind: kind, start: point, points: kind == .pen ? [point] : [], style: viewModel.creationStyle(for: viewModel.tool)
        )
        viewModel.selectedID = nil
        viewModel.replaceLive(snapshot.adding(annotation))
        dragState = .creating(id: annotation.id, snapshot: snapshot)
    }

    /// Starts resizing the selected annotation when a handle is under the cursor.
    private func beginHandleDrag(at point: CGPoint, tolerance: CGFloat) -> Bool {
        guard let selected = viewModel.selectedAnnotation,
              let handle = HitTesting.handle(of: selected, at: point, tolerance: tolerance * 1.5)
        else { return false }
        dragState = .resizing(id: selected.id, handle: handle, snapshot: viewModel.document)
        return true
    }

    private func beginCropDrag(at point: CGPoint, tolerance: CGFloat) {
        let draft = viewModel.cropDraft
        if let draft,
           let handle = Resizing.cornerHandles(of: draft)
               .first(where: { $0.point.distance(to: point) <= tolerance * 1.5 })?.kind {
            dragState = .cropResizing(handle: handle)
        } else if let draft, draft.contains(point) {
            dragState = .cropMoving(last: point)
        } else {
            let origin = Geometry.clamp(point, to: viewModel.document.canvasRect)
            dragState = .cropNew(origin: origin, previous: draft)
            viewModel.cropDraft = CGRect(origin: origin, size: .zero)
        }
    }

    func startTextEditing(existing id: UUID?, at point: CGPoint) {
        dragState = .idle
        let annotation = viewModel.beginTextEdit(existing: id, at: point)
        textEditor.begin(annotation: annotation)
    }

    // MARK: - Mouse dragged

    override func mouseDragged(with event: NSEvent) {
        let point = documentPoint(for: event)
        let constrain = event.modifierFlags.contains(.shift)
        switch dragState {
        case .idle:
            return
        case let .creating(id, _):
            updateCreating(id: id, to: point, constrain: constrain)
        case let .movingGroup(ids, last, snapshot):
            viewModel.replaceLive(viewModel.document.moving(ids: ids, by: point - last))
            dragState = .movingGroup(ids: ids, last: point, snapshot: snapshot)
        case let .marquee(origin, base):
            updateMarquee(from: origin, to: point, base: base)
        case let .moving(id, part, last, snapshot):
            guard let annotation = viewModel.document.annotation(id: id) else { return }
            viewModel.replaceLive(viewModel.document.replacing(move(annotation, part: part, by: point - last)))
            dragState = .moving(id: id, part: part, last: point, snapshot: snapshot)
        case let .resizing(id, handle, snapshot):
            guard let original = snapshot.annotation(id: id) else { return }
            let resized = Resizing.resize(original, handle: handle, to: point, constrain: constrain)
            viewModel.replaceLive(viewModel.document.replacing(resized))
        case let .panning(last):
            let current = convert(event.locationInWindow, from: nil)
            pan(by: current - last)
            dragState = .panning(last: current)
        case .cropNew, .cropMoving, .cropResizing:
            updateCrop(to: point, constrain: constrain)
        }
    }

    private func updateCreating(id: UUID, to point: CGPoint, constrain: Bool) {
        guard let annotation = viewModel.document.annotation(id: id) else { return }
        let updated: Annotation = if annotation.kind == .pen {
            annotation.appending(point: point)
        } else if annotation.kind == .magnifier {
            annotation.with(end: Geometry.square(from: annotation.start, to: point)).withDefaultCallout()
        } else if annotation.kind.isSegment {
            annotation.with(end: constrain ? Geometry.snap45(from: annotation.start, to: point) : point)
        } else {
            annotation.with(end: constrain ? Geometry.square(from: annotation.start, to: point) : point)
        }
        // Smart erase previews the sampled color while dragging.
        viewModel.replaceLive(viewModel.document.replacing(viewModel.sampledFill(updated)))
    }

    private func updateCrop(to point: CGPoint, constrain: Bool) {
        let bounds = viewModel.document.canvasRect
        let clamped = Geometry.clamp(point, to: bounds)
        switch dragState {
        case let .cropNew(origin, _):
            let end = viewModel.cropAspect.ratio.map { Geometry.aspect(from: origin, to: clamped, ratio: $0) }
                ?? (constrain ? Geometry.square(from: origin, to: clamped) : clamped)
            viewModel.cropDraft = Geometry.rect(from: origin, to: end).intersection(bounds)
        case let .cropMoving(last):
            guard let draft = viewModel.cropDraft else { return }
            let delta = point - last
            let moved = draft.offsetBy(dx: delta.x, dy: delta.y)
            let x = min(max(moved.minX, bounds.minX), bounds.maxX - moved.width)
            let y = min(max(moved.minY, bounds.minY), bounds.maxY - moved.height)
            viewModel.cropDraft = CGRect(x: x, y: y, width: moved.width, height: moved.height)
            dragState = .cropMoving(last: point)
        case let .cropResizing(handle):
            guard let draft = viewModel.cropDraft else { return }
            viewModel.cropDraft = Resizing.resize(
                rect: draft, handle: handle, to: clamped, constrain: constrain, aspect: viewModel.cropAspect.ratio
            )
        default:
            return
        }
    }

    // MARK: - Mouse up

    override func mouseUp(with event: NSEvent) {
        let state = dragState
        dragState = .idle
        switch state {
        case .idle, .cropMoving, .cropResizing:
            return
        case .panning:
            window?.invalidateCursorRects(for: self)
        case let .creating(id, snapshot):
            finishCreating(id: id, snapshot: snapshot)
        case let .movingGroup(ids, _, snapshot):
            ids.forEach(resampleFill(id:))
            viewModel.commit(from: snapshot, actionName: String(localized: "Move", bundle: .module))
        case .marquee:
            endMarquee()
        case let .moving(id, _, _, snapshot):
            resampleFill(id: id)
            viewModel.commit(from: snapshot, actionName: String(localized: "Move", bundle: .module))
        case let .resizing(id, _, snapshot):
            resampleFill(id: id)
            viewModel.commit(from: snapshot, actionName: String(localized: "Resize", bundle: .module))
        case let .cropNew(_, previous):
            if let draft = viewModel.cropDraft, draft.width < Self.minimumShapeSize || draft.height < Self.minimumShapeSize {
                viewModel.cropDraft = previous ?? viewModel.document.canvasRect
            }
        }
    }

    private func finishCreating(id: UUID, snapshot: EditorDocument) {
        guard let annotation = viewModel.document.annotation(id: id) else { return }
        guard isLargeEnough(annotation) else {
            viewModel.replaceLive(snapshot)
            return
        }
        resampleFill(id: id)
        viewModel.commit(from: snapshot, actionName: String(localized: "Add \(annotation.kind.displayName)", bundle: .module))
        viewModel.selectedID = id
    }

    func resampleFill(id: UUID) {
        guard let annotation = viewModel.document.annotation(id: id), annotation.kind == .fill else { return }
        viewModel.replaceLive(viewModel.document.replacing(viewModel.sampledFill(annotation)))
    }

    private func move(_ annotation: Annotation, part: MovePart, by delta: CGPoint) -> Annotation {
        switch part {
        case .whole: return annotation.moved(by: delta)
        case .magnifierSource: return annotation.movedSource(by: delta)
        case .magnifierCallout: return annotation.movedCallout(by: delta)
        }
    }

    private func isLargeEnough(_ annotation: Annotation) -> Bool {
        let minimum = Self.minimumShapeSize
        switch annotation.kind {
        case .pen: return annotation.points.count > 1
        case .arrow, .line: return annotation.start.distance(to: annotation.end) >= minimum
        default: return annotation.rect.width >= minimum && annotation.rect.height >= minimum
        }
    }
}
