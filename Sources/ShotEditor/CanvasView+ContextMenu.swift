import AppKit

/// Right-click menus: selection actions on a hit, canvas actions elsewhere.
extension CanvasView {
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !textEditor.isEditing, viewModel.tool != .crop else { return nil }
        let point = documentPoint(for: event)
        let tolerance = layout.documentLength(Self.hitTolerance)
        if let hit = HitTesting.topmost(in: viewModel.document, at: point, tolerance: tolerance) {
            // Right-clicking inside a multi-selection acts on the whole group.
            if !viewModel.selectedIDs.contains(hit.id) { viewModel.selectedID = hit.id }
            return MenuBuilder.menu(selectionEntries(for: viewModel.selectedAnnotations))
        }
        return MenuBuilder.menu(canvasEntries)
    }

    private func selectionEntries(for annotations: [Annotation]) -> [MenuEntry] {
        let ids = Set(annotations.map(\.id))
        let viewModel = viewModel
        var entries: [MenuEntry] = [
            .action(String(localized: "Duplicate", bundle: .module), symbol: "plus.square.on.square", key: "d", modifiers: .command) {
                viewModel.duplicate(ids: ids)
            },
            .action(String(localized: "Copy", bundle: .module), symbol: "doc.on.doc", key: "c", modifiers: .command) {
                _ = viewModel.copySelection()
            },
            .separator,
            .action(String(localized: "Bring to Front", bundle: .module), symbol: "square.3.layers.3d.top.filled") {
                viewModel.bringToFront(ids: ids)
            },
            .action(String(localized: "Send to Back", bundle: .module), symbol: "square.3.layers.3d.bottom.filled") {
                viewModel.sendToBack(ids: ids)
            },
        ]
        let colored = annotations.filter { EditorTool(kind: $0.kind)?.usesColor == true }
        if let first = colored.first {
            let current = colored.allSatisfy { $0.style.color == first.style.color } ? first.style.color : nil
            entries.append(.separator)
            entries.append(.submenu(
                String(localized: "Color", bundle: .module),
                symbol: "paintpalette",
                colorEntries(ids: ids, current: current)
            ))
        }
        entries.append(.separator)
        entries.append(selectAllEntry)
        entries.append(.action(String(localized: "Delete", bundle: .module), symbol: "trash") { viewModel.delete(ids: ids) })
        return entries
    }

    private func colorEntries(ids: Set<UUID>, current: AnnotationColor?) -> [MenuEntry] {
        let viewModel = viewModel
        return zip(AnnotationColor.palette, Self.colorNames).map { color, name in
            .action(name, image: MenuBuilder.swatch(color), isOn: color == current) { viewModel.recolor(ids: ids, to: color) }
        }
    }

    private var selectAllEntry: MenuEntry {
        let viewModel = viewModel
        return .action(
            String(localized: "Select All", bundle: .module), symbol: "checklist",
            isEnabled: !viewModel.document.annotations.isEmpty, key: "a", modifiers: .command
        ) { viewModel.selectAll() }
    }

    private var canvasEntries: [MenuEntry] {
        let viewModel = viewModel
        return [
            .action(String(localized: "Paste", bundle: .module), symbol: "doc.on.clipboard", key: "v", modifiers: .command) {
                viewModel.paste()
            },
            .action(String(localized: "Copy Image", bundle: .module), symbol: "photo.on.rectangle", key: "c", modifiers: .command) {
                viewModel.export(.copy)
            },
            .separator,
            selectAllEntry,
        ]
    }

    /// Names matching `AnnotationColor.palette` order.
    private static var colorNames: [String] {
        [
            String(localized: "Red", bundle: .module),
            String(localized: "Orange", bundle: .module),
            String(localized: "Yellow", bundle: .module),
            String(localized: "Green", bundle: .module),
            String(localized: "Blue", bundle: .module),
            String(localized: "Black", bundle: .module),
            String(localized: "White", bundle: .module),
        ]
    }
}
