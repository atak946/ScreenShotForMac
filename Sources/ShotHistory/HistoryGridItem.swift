import AppKit
import AVFoundation
import ShotCore
import SwiftUI

/// One grid tile: aspect-fit thumbnail in a uniform card, kind badge, hover lift with glass
/// quick actions, selection ring, context menu, drag-out.
struct HistoryGridItem: View {
    let item: HistoryItem
    let isThumbnailPending: Bool
    let isSelected: Bool
    let model: HistoryBrowserModel
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var fileSize: Int64?
    @State private var duration: TimeInterval?
    @State private var isHovering = false

    private static let tileAspect: CGFloat = 4 / 3
    private static let ringWidth: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            tile
            caption
        }
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { model.open(item) })
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        .onHover { isHovering = $0 }
        .onDrag { model.dragProvider(for: item) }
        .contextMenu { contextMenu }
        .task(id: LoadKey(id: item.id, isPending: isThumbnailPending)) { await load() }
        .help(details)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(details)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.open(item) }
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        return Color.primary.opacity(0.04)
            .aspectRatio(Self.tileAspect, contentMode: .fit)
            .overlay { thumbnailView.padding(DS.Space.s) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.dsStroke, lineWidth: DS.Size.hairline))
            .overlay(alignment: .bottomLeading) { kindBadge }
            .overlay(alignment: .topTrailing) { if isHovering { quickActions } }
            .background(shape.fill(Color(nsColor: .windowBackgroundColor)))
            .shadow(color: .black.opacity(isHovering ? 0.18 : 0.06), radius: isHovering ? 12 : 3, y: isHovering ? 6 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card + Self.ringWidth, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: Self.ringWidth)
                    .padding(-Self.ringWidth - 1)
                    .opacity(isSelected ? 1 : 0)
            }
            .scaleEffect(isHovering ? 1.02 : 1)
            .animation(.easeOut(duration: DS.Motion.fast), value: isHovering)
            .animation(.easeOut(duration: DS.Motion.fast), value: isSelected)
    }

    @ViewBuilder private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        } else if isThumbnailPending {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: placeholderSymbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var kindBadge: some View {
        if let label = badgeText {
            HStack(spacing: 3) {
                if item.kind == .video {
                    Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                }
                Text(verbatim: label)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .glassSurface(cornerRadius: 10)
            .padding(DS.Space.s)
        }
    }

    private var quickActions: some View {
        HStack(spacing: DS.Space.xxs) {
            quickAction("doc.on.doc", String(localized: "Copy", bundle: .module)) { model.copy(item) }
            quickAction("folder", String(localized: "Reveal in Finder", bundle: .module)) { model.reveal(item) }
            quickAction("trash", String(localized: "Delete…", bundle: .module)) { model.confirmDelete(item) }
        }
        .padding(DS.Space.xxs)
        .glassSurface(cornerRadius: DS.Radius.control + DS.Space.xxs)
        .padding(DS.Space.s)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
    }

    private func quickAction(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(ToolButtonStyle(size: 24))
            .help(title)
            .accessibilityLabel(title)
    }

    private var caption: some View {
        HStack(spacing: DS.Space.xs) {
            Text(item.sourceAppName ?? String(localized: "Unknown app", bundle: .module))
                .foregroundStyle(.primary)
            Spacer(minLength: DS.Space.xs)
            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, DS.Space.xxs)
    }

    @ViewBuilder private var contextMenu: some View {
        Button(String(localized: "Open", bundle: .module)) { model.open(item) }
        Button(String(localized: "Quick Look", bundle: .module)) { model.quickLookItem = item }
        Divider()
        Button(String(localized: "Copy", bundle: .module)) { model.copy(item) }
        Button(String(localized: "Reveal in Finder", bundle: .module)) { model.reveal(item) }
        Divider()
        Button(String(localized: "Delete…", bundle: .module), role: .destructive) { model.confirmDelete(item) }
    }

    private var badgeText: String? {
        switch item.kind {
        case .image: return nil
        case .gif: return "GIF"
        case .video: return duration.map(Self.formatDuration) ?? ""
        }
    }

    private var sizeText: String {
        let pixels = "\(Int(item.pixelSize.width)) × \(Int(item.pixelSize.height))"
        guard let fileSize else { return pixels }
        return "\(pixels) · \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))"
    }

    private var details: String {
        let kind = item.kind == .image
            ? String(localized: "Screenshot", bundle: .module)
            : (item.kind == .gif ? "GIF" : String(localized: "Video", bundle: .module))
        let date = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        guard let app = item.sourceAppName else { return "\(kind), \(date), \(sizeText)" }
        return String(localized: "\(kind) from \(app), \(date), \(sizeText)", bundle: .module)
    }

    private var placeholderSymbol: String {
        switch item.kind {
        case .image: return "photo"
        case .video: return "video"
        case .gif: return "photo.stack"
        }
    }

    private func load() async {
        guard !isThumbnailPending else { return }
        thumbnail = await ThumbnailCache.shared.image(for: item.thumbnailURL)
        let url = item.fileURL
        fileSize = await Task.detached(priority: .utility) { HistoryFileWriter.fileSize(at: url) }.value
        if item.kind == .video {
            duration = await Self.loadDuration(of: url)
        }
    }

    private nonisolated static func loadDuration(of url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let time = try? await asset.load(.duration), time.isNumeric else { return nil }
        return time.seconds
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private struct LoadKey: Equatable {
        let id: UUID
        let isPending: Bool
    }
}
