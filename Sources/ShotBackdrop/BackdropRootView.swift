import ShotCore
import SwiftUI

/// Root layout: live preview on the left, inspector sidebar on the right, actions in the toolbar.
struct BackdropRootView: View {
    static let inspectorWidth: CGFloat = 280
    static let minimumSize = CGSize(width: 820, height: 540)

    @Bindable var model: BackdropViewModel

    var body: some View {
        HStack(spacing: 0) {
            BackdropPreviewView(model: model)
            Divider()
            BackdropInspector(model: model)
                .frame(width: Self.inspectorWidth)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .navigationTitle(Text("Backdrop", bundle: .module))
        .navigationSubtitle(Text(verbatim: "\(model.capture.image.width) × \(model.capture.image.height)"))
        .toolbar { BackdropToolbar(model: model) }
        .background { BackdropShortcuts(model: model) }
    }
}

/// Toolbar: Copy (icon) and a Save pill with Save As in a dropdown.
struct BackdropToolbar: ToolbarContent {
    let model: BackdropViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.export(.copy) } label: {
                Label(String(localized: "Copy", bundle: .module), systemImage: "doc.on.doc")
            }
            .help(String(localized: "Copy to Clipboard (⌘C)", bundle: .module))

            HStack(spacing: DS.Space.xxs) {
                Button(String(localized: "Save", bundle: .module)) { model.export(.save) }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .help(String(localized: "Save (⌘S)", bundle: .module))
                Menu {
                    Button(String(localized: "Save As…", bundle: .module)) { model.export(.saveAs) }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(String(localized: "More Save Options", bundle: .module))
            }
        }
    }
}

/// Invisible buttons that own the window's keyboard shortcuts (toolbar items and menus
/// don't reliably receive key equivalents in a bridged hosting window).
private struct BackdropShortcuts: View {
    let model: BackdropViewModel

    var body: some View {
        ZStack {
            shortcut("c", [.command]) { model.export(.copy) }
            shortcut("s", [.command]) { model.export(.save) }
            shortcut("s", [.command, .shift]) { model.export(.saveAs) }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func shortcut(_ key: KeyEquivalent, _ modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(.plain)
            .keyboardShortcut(key, modifiers: modifiers)
    }
}

/// Live, downscaled preview of the composed image on a dot-grid canvas.
struct BackdropPreviewView: View {
    let model: BackdropViewModel

    var body: some View {
        ZStack {
            DotGridBackground()
            previewImage
                .padding(DS.Space.xxl)
                .padding(.bottom, DS.Space.l)
        }
        .animation(.easeOut(duration: DS.Motion.fast), value: model.previewGeneration)
        .overlay(alignment: .bottom) { sizeBadge }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Backdrop preview", bundle: .module))
    }

    @ViewBuilder private var previewImage: some View {
        if let preview = model.preview {
            let isTransparent = model.style.background == .none
            Image(decorative: preview, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: CGFloat(preview.width), maxHeight: CGFloat(preview.height))
                .background(CheckerboardView().opacity(isTransparent ? 1 : 0))
                .shadow(color: .black.opacity(isTransparent ? 0 : 0.18), radius: 16, y: 6)
                .id(model.previewGeneration)
                .transition(.opacity)
        } else {
            Text("Preview unavailable", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private var sizeBadge: some View {
        let size = model.outputPixelSize
        return Text(verbatim: "\(Int(size.width)) × \(Int(size.height)) px")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .glassSurface(cornerRadius: 10)
            .padding(.bottom, DS.Space.m)
            .accessibilityLabel(Text("Output size \(Int(size.width)) by \(Int(size.height)) pixels", bundle: .module))
    }
}

/// Neutral canvas with a subtle dot grid.
struct DotGridBackground: View {
    private let spacing: CGFloat = 16
    private let dotSize: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(.primary.opacity(0.12)))
        }
        .background(Color.dsCanvas)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Transparency indicator behind images with a clear background.
struct CheckerboardView: View {
    private let cell: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / cell) + 1
            let rows = Int(size.height / cell) + 1
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var dark = Path()
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    dark.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(dark, with: .color(Color(white: 0.85)))
        }
    }
}
