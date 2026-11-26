import ShotCore
import SwiftUI

/// Live, downscaled preview of the combined image on a dot-grid canvas.
struct CombinePreviewView: View {
    let model: CombineViewModel

    var body: some View {
        ZStack {
            DotGridBackground()
            content
                .padding(DS.Space.xxl)
                .padding(.bottom, DS.Space.l)
        }
        .animation(.easeOut(duration: DS.Motion.fast), value: model.previewGeneration)
        .overlay(alignment: .bottom) { if !model.items.isEmpty { sizeBadge } }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Combined preview", bundle: .module))
    }

    @ViewBuilder private var content: some View {
        if model.items.isEmpty {
            EmptyWorkspaceView(model: model)
        } else if let preview = model.preview {
            let isTransparent = !model.layout.fillsBackground
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
            ProgressView().controlSize(.small)
        }
    }

    private var sizeBadge: some View {
        SizeBadge(size: model.outputPixelSize)
    }
}

/// Glass capsule with a pixel size readout.
struct SizeBadge: View {
    let size: CGSize

    var body: some View {
        Text(verbatim: "\(Int(size.width)) × \(Int(size.height)) px")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .glassSurface(cornerRadius: 10)
            .padding(.bottom, DS.Space.m)
            .accessibilityLabel(Text("Output size \(Int(size.width)) by \(Int(size.height)) pixels", bundle: .module))
    }
}

/// Shown when no images are loaded yet.
struct EmptyWorkspaceView: View {
    let model: CombineViewModel

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop images here", bundle: .module)
                .font(.system(size: 15, weight: .semibold))
            Text("Or paste with ⌘V, or add files from disk.", bundle: .module)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button(String(localized: "Add Images…", bundle: .module)) { model.addFromPanel() }
                .buttonStyle(PrimaryPillButtonStyle())
                .padding(.top, DS.Space.xs)
        }
        .padding(DS.Space.xl)
        .glassSurface(cornerRadius: DS.Radius.panel)
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
