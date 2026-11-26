import AppKit

extension CanvasView {
    private enum KeyCode {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let space: UInt16 = 49
    }

    override func keyUp(with event: NSEvent) {
        guard event.keyCode == KeyCode.space else {
            super.keyUp(with: event)
            return
        }
        isSpacePressed = false
        window?.invalidateCursorRects(for: self)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command), !flags.contains(.control) else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == KeyCode.space {
            if !event.isARepeat {
                isSpacePressed = true
                window?.invalidateCursorRects(for: self)
            }
            return
        }
        if handleSpecialKey(event, shift: flags.contains(.shift)) { return }
        if let character = event.charactersIgnoringModifiers?.lowercased().first,
           let tool = EditorTool(shortcut: character) {
            viewModel.selectTool(tool)
            return
        }
        super.keyDown(with: event)
    }

    private func handleSpecialKey(_ event: NSEvent, shift: Bool) -> Bool {
        let step: CGFloat = shift ? 10 : 1
        switch event.keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            if viewModel.tool == .crop { viewModel.applyCrop() }
            return true
        case KeyCode.escape:
            // Esc cancels crop, otherwise clears the selection and returns to Select.
            if viewModel.tool == .crop {
                viewModel.cancelCrop()
            } else {
                viewModel.selectedID = nil
                viewModel.selectTool(.select)
            }
            return true
        case KeyCode.delete, KeyCode.forwardDelete:
            viewModel.deleteSelected()
            return true
        case KeyCode.left: viewModel.nudgeSelected(by: CGPoint(x: -step, y: 0))
            return true
        case KeyCode.right: viewModel.nudgeSelected(by: CGPoint(x: step, y: 0))
            return true
        case KeyCode.up: viewModel.nudgeSelected(by: CGPoint(x: 0, y: -step))
            return true
        case KeyCode.down: viewModel.nudgeSelected(by: CGPoint(x: 0, y: step))
            return true
        default:
            return false
        }
    }

    /// The app is an LSUIElement without a main menu, so command shortcuts are handled here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !textEditor.isEditing, window?.isKeyWindow == true else {
            return super.performKeyEquivalent(with: event)
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let shift = flags.contains(.shift)
        switch key {
        case "z":
            if shift { viewModel.redo() } else { viewModel.undo() }
        case "c" where !shift:
            if !viewModel.copySelection() { viewModel.export(.copy) }
        case "v" where !shift:
            viewModel.paste()
        case "a" where !shift:
            viewModel.selectAll()
        case "d" where !shift:
            viewModel.duplicate(ids: viewModel.selectedIDs)
        case "=", "+":
            viewModel.zoom(.zoomIn)
        case "-":
            viewModel.zoom(.zoomOut)
        case "0":
            viewModel.zoom(.fit)
        case "1":
            viewModel.zoom(.actualSize)
        case "s":
            viewModel.export(shift ? .saveAs : .save)
        case "w" where !shift:
            window?.performClose(nil)
        default:
            return super.performKeyEquivalent(with: event)
        }
        return true
    }
}
