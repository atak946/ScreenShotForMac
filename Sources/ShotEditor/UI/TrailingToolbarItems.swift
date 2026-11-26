import ShotCore
import SwiftUI

/// Trailing toolbar zone: zoom, "…" menu, Pin / Backdrop, Copy and the Save pill.
struct TrailingToolbarItems: View {
    let viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            ZoomMenuButton(viewModel: viewModel)
            PopUpMenuButton(help: String(localized: "More", bundle: .module), entries: { moreEntries }) {
                Image(systemName: "ellipsis.circle").font(.system(size: DS.Size.symbolPointSize, weight: .medium))
            }
            if viewModel.canAutoRedact {
                AutoRedactButton(viewModel: viewModel)
            }
            ToolbarDivider()
            if viewModel.onPin != nil {
                iconButton("pin", help: String(localized: "Pin to Screen", bundle: .module)) { viewModel.pin() }
            }
            if viewModel.onBackdrop != nil {
                iconButton("photo.artframe", help: String(localized: "Backdrop…", bundle: .module)) { viewModel.backdrop() }
            }
            iconButton("doc.on.doc", help: String(localized: "Copy to Clipboard", bundle: .module) + "  ⌘C") {
                viewModel.export(.copy)
            }
            if viewModel.onUpload != nil {
                iconButton("icloud.and.arrow.up", help: String(localized: "Upload", bundle: .module)) { viewModel.upload() }
            }
            SaveButton(viewModel: viewModel)
                .padding(.leading, DS.Space.xs)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(ToolButtonStyle())
            .help(help)
            .accessibilityLabel(help)
    }

    private var moreEntries: [MenuEntry] {
        redactEntries + [
            .action(String(localized: "Rotate Left", bundle: .module), symbol: "rotate.left") { viewModel.transform(.rotateLeft) },
            .action(String(localized: "Rotate Right", bundle: .module), symbol: "rotate.right") { viewModel.transform(.rotateRight) },
            .action(
                String(localized: "Flip Horizontal", bundle: .module),
                symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right"
            ) { viewModel.transform(.flipHorizontal) },
            .separator,
            .submenu(String(localized: "Canvas Padding", bundle: .module), symbol: "rectangle.dashed", paddingEntries),
            .submenu(String(localized: "Canvas Background", bundle: .module), symbol: "paintbrush", backgroundEntries),
            .separator,
            .submenu(String(localized: "Insert Stamp", bundle: .module), symbol: "face.smiling", stampEntries),
        ]
    }

    private var redactEntries: [MenuEntry] {
        guard viewModel.canAutoRedact else { return [] }
        return [
            .action(String(localized: "Auto Redact", bundle: .module), symbol: "eye.slash", isEnabled: !viewModel.isRedacting) {
                viewModel.autoRedact()
            },
            .separator,
        ]
    }

    private var paddingEntries: [MenuEntry] {
        EditorDocument.paddingOptions.map { padding in
            let title = padding == 0 ? String(localized: "None", bundle: .module) : "\(Int(padding)) pt"
            return .action(title, isOn: viewModel.document.canvasPadding == padding) { viewModel.setPadding(padding) }
        }
    }

    private var backgroundEntries: [MenuEntry] {
        let current = viewModel.document.backgroundColor
        return [
            .action(String(localized: "Transparent", bundle: .module), isOn: current == nil) { viewModel.setBackground(nil) },
            .action(String(localized: "White", bundle: .module), image: MenuBuilder.swatch(.white), isOn: current == .white) {
                viewModel.setBackground(.white)
            },
            .action(String(localized: "Black", bundle: .module), image: MenuBuilder.swatch(.black), isOn: current == .black) {
                viewModel.setBackground(.black)
            },
            .action(String(localized: "Current Color", bundle: .module), image: MenuBuilder.swatch(viewModel.style.color)) {
                viewModel.setBackground(viewModel.style.color)
            },
        ]
    }

    private var stampEntries: [MenuEntry] {
        EditorViewModel.stamps.map { stamp in .action(stamp) { viewModel.insertStamp(stamp) } }
    }
}

/// Compact "100%" button with the zoom menu.
private struct ZoomMenuButton: View {
    let viewModel: EditorViewModel

    var body: some View {
        PopUpMenuButton(help: String(localized: "Zoom", bundle: .module), entries: { entries }) {
            HStack(spacing: 3) {
                Text(verbatim: "\(viewModel.zoomPercent)%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(minWidth: 34, alignment: .trailing)
                MenuChevron()
            }
        }
    }

    private var entries: [MenuEntry] {
        [
            .header(viewModel.outputDimensionsLabel),
            .action(String(localized: "Zoom In", bundle: .module), key: "+", modifiers: .command) { viewModel.zoom(.zoomIn) },
            .action(String(localized: "Zoom Out", bundle: .module), key: "-", modifiers: .command) { viewModel.zoom(.zoomOut) },
            .separator,
            .action(String(localized: "Zoom to Fit", bundle: .module), key: "0", modifiers: .command) { viewModel.zoom(.fit) },
            .action(String(localized: "Actual Size", bundle: .module), key: "1", modifiers: .command) { viewModel.zoom(.actualSize) },
            .separator,
            .action("200%", isOn: viewModel.zoomPercent == 200) { viewModel.zoom(.set(2)) },
            .action("400%", isOn: viewModel.zoomPercent == 400) { viewModel.zoom(.set(4)) },
            .action("800%", isOn: viewModel.zoomPercent == 800) { viewModel.zoom(.set(8)) },
        ]
    }
}

/// Prominent Save pill; its chevron opens "Save As…".
private struct SaveButton: View {
    private static let chevronWidth: CGFloat = 22

    let viewModel: EditorViewModel
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button { viewModel.export(.save) } label: {
            HStack(spacing: DS.Space.s) {
                Text(String(localized: "Save", bundle: .module))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 14)
                MenuChevron().frame(width: Self.chevronWidth - DS.Space.m)
            }
        }
        .buttonStyle(PrimaryPillButtonStyle())
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: Self.chevronWidth + DS.Space.xs)
                .contentShape(Rectangle())
                .onTapGesture { anchor.popUp(entries) }
                .menuAnchor(anchor)
                .help(String(localized: "More Save Options", bundle: .module))
        }
        .help(String(localized: "Save", bundle: .module) + "  ⌘S")
        .accessibilityLabel(String(localized: "Save", bundle: .module))
    }

    private var entries: [MenuEntry] {
        [
            .action(String(localized: "Save", bundle: .module), key: "s", modifiers: .command) { viewModel.export(.save) },
            .action(String(localized: "Save As…", bundle: .module), key: "s", modifiers: [.command, .shift]) {
                viewModel.export(.saveAs)
            },
        ]
    }
}
