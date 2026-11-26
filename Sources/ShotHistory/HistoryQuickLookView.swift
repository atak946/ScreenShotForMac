import AppKit
import AVKit
import ShotCore
import SwiftUI

/// Space-bar preview sheet: the full image / animated GIF / playable video with quick actions.
struct HistoryQuickLookView: View {
    let item: HistoryItem
    let model: HistoryBrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dsCanvas)
        }
        .frame(minWidth: 640, idealWidth: 900, minHeight: 440, idealHeight: 620)
        .onKeyPress(.space) {
            dismiss()
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.sourceAppName ?? String(localized: "Unknown app", bundle: .module))
                    .font(.headline)
                Text(
                    verbatim: "\(item.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(Int(item.pixelSize.width)) × \(Int(item.pixelSize.height))"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.copy(item) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(ToolButtonStyle())
                .help(String(localized: "Copy", bundle: .module))
            Button { model.reveal(item) } label: { Image(systemName: "folder") }
                .buttonStyle(ToolButtonStyle())
                .help(String(localized: "Reveal in Finder", bundle: .module))
            Button(String(localized: "Open", bundle: .module)) {
                dismiss()
                model.open(item)
            }
            .buttonStyle(PrimaryPillButtonStyle())
            Button(String(localized: "Done", bundle: .module)) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
    }

    @ViewBuilder private var preview: some View {
        if item.kind == .video {
            VideoPlayer(player: AVPlayer(url: item.fileURL))
        } else {
            QuickLookImage(url: item.fileURL)
                .padding(DS.Space.xl)
        }
    }
}

/// Loads the file off the main thread and shows it in an `NSImageView` (animates GIFs).
private struct QuickLookImage: View {
    let url: URL
    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                AnimatedImageView(image: image)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            } else if didFail {
                ContentUnavailableView(
                    String(localized: "The file for this capture could not be read.", bundle: .module),
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                ProgressView()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        let url = url
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            do {
                return try Data(contentsOf: url)
            } catch {
                Log.export.error("Quick Look could not read history file: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }.value
        image = data.flatMap(NSImage.init(data:))
        didFail = image == nil
    }
}

private struct AnimatedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        view.animates = true
        view.isEditable = false
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        if view.image !== image { view.image = image }
    }
}
