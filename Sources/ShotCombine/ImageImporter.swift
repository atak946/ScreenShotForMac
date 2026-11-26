import AppKit
import ShotCore
import UniformTypeIdentifiers

/// Collects images from the open panel, the pasteboard and drag & drop.
@MainActor
enum ImageImporter {
    /// Drop types accepted by the window.
    static let dropTypes: [UTType] = [.fileURL, .image]

    /// Shows an open panel (sheet when `window` is given) and delivers the chosen images.
    static func chooseImages(for window: NSWindow?, completion: @escaping @MainActor ([CombineImage]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = String(localized: "Choose images to add", bundle: .module)
        panel.prompt = String(localized: "Add", bundle: .module)
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            completion(panel.urls.compactMap(loadLogging))
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Images (or image files) currently on the general pasteboard.
    static func imagesFromPasteboard(_ pasteboard: NSPasteboard = .general) -> [CombineImage] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            return urls.compactMap(loadLogging)
        }
        let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] ?? []
        return images.compactMap { image in
            var rect = CGRect(origin: .zero, size: image.size)
            guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
            let scale = image.size.width > 0 ? CGFloat(cgImage.width) / image.size.width : 1
            return CombineImage(image: cgImage, scale: max(1, scale.rounded()))
        }
    }

    /// Loads dropped providers in the background; delivers each decoded image on the main actor.
    static func load(providers: [NSItemProvider], deliver: @escaping @MainActor (CombineImage) -> Void) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                loadFileURL(from: provider, deliver: deliver)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                accepted = true
                loadImageData(from: provider, deliver: deliver)
            }
        }
        return accepted
    }

    private static func loadFileURL(from provider: NSItemProvider, deliver: @escaping @MainActor (CombineImage) -> Void) {
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
            guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                Log.editor.error("Dropped file URL unreadable: \(String(describing: error), privacy: .public)")
                return
            }
            guard let image = ImageLoading.load(url: url) else {
                Log.editor.info("Dropped file is not an image: \(url.lastPathComponent, privacy: .public)")
                return
            }
            Task { @MainActor in deliver(image) }
        }
    }

    private static func loadImageData(from provider: NSItemProvider, deliver: @escaping @MainActor (CombineImage) -> Void) {
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
            guard let data, let image = ImageLoading.load(data: data) else {
                Log.editor.error("Dropped image data unreadable: \(String(describing: error), privacy: .public)")
                return
            }
            Task { @MainActor in deliver(image) }
        }
    }

    private static func loadLogging(_ url: URL) -> CombineImage? {
        let image = ImageLoading.load(url: url)
        if image == nil {
            Log.editor.error("Could not load image \(url.lastPathComponent, privacy: .public)")
        }
        return image
    }

    /// Asks for a destination folder for "Save All…".
    static func chooseFolder(for window: NSWindow?, completion: @escaping @MainActor (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a folder for the slices", bundle: .module)
        panel.prompt = String(localized: "Save All", bundle: .module)
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }
}
