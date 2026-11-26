import AppKit
import CoreGraphics
import Foundation
import ShotCore

/// Clipboard and file export for captures.
@MainActor
public final class ExportService: ExportServicing {
    let settings: AppSettings
    private let template = FilenameTemplate()

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    // MARK: Clipboard

    public func copyToClipboard(_ image: CGImage, scale: CGFloat) {
        let prepared = ImageScaler.prepare(image, scale: scale, downscale: settings.downscaleRetina)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = Self.makeNSImage(prepared.image, scale: prepared.scale)
        var items: [NSPasteboardWriting] = []
        if let png = try? ImageEncoder.pngData(for: prepared.image, scale: prepared.scale) {
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = nsImage.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
            items.append(item)
        } else {
            Log.export.error("PNG encoding failed for clipboard; falling back to NSImage")
            items.append(nsImage)
        }
        if !pasteboard.writeObjects(items) {
            Log.export.error("Failed to write image to the pasteboard")
        }
    }

    public func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(text, forType: .string) {
            Log.export.error("Failed to write text to the pasteboard")
        }
    }

    // MARK: Files

    @discardableResult
    public func save(_ image: CGImage, scale: CGFloat, context: FilenameContext) throws -> URL {
        let format = settings.imageFormat
        let data = try encode(image, scale: scale, format: format)
        let baseName = renderName(context: context)
        return try SaveLocation(settings: settings).withFolder { folder in
            let url = SaveLocation.uniqueURL(in: folder, baseName: baseName, fileExtension: format.fileExtension)
            try write(data, to: url)
            return url
        }
    }

    @discardableResult
    public func saveAs(_ image: CGImage, scale: CGFloat, context: FilenameContext) throws -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = String(localized: "Save Screenshot", bundle: .module)
        panel.nameFieldStringValue = "\(renderName(context: context)).\(settings.imageFormat.fileExtension)"
        if let folder = try? SaveLocation(settings: settings).withFolder({ $0 }) {
            panel.directoryURL = folder
        }
        let accessory = SaveFormatAccessory(panel: panel, initial: settings.imageFormat)
        panel.accessoryView = accessory.view
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let format = accessory.selectedFormat
        let finalURL = url.pathExtension.lowercased() == format.fileExtension
            ? url
            : url.deletingPathExtension().appendingPathExtension(format.fileExtension)
        let data = try encode(image, scale: scale, format: format)
        try write(data, to: finalURL)
        return finalURL
    }

    /// Lets the user pick a save folder and stores a security-scoped bookmark. Returns true on success.
    @discardableResult
    public func chooseSaveFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose", bundle: .module)
        panel.message = String(localized: "Choose where screenshots are saved", bundle: .module)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try SaveLocation(settings: settings).store(folder: url)
            Log.export.info("Save folder updated")
            return true
        } catch {
            Log.export.error("Storing save folder failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Helpers

    func encodeForExport(_ image: CGImage, scale: CGFloat, format: ImageFormat) throws -> Data {
        try encode(image, scale: scale, format: format)
    }

    /// Base filename (no extension) from the user's filename template.
    public func suggestedFilename(context: FilenameContext) -> String {
        renderName(context: context)
    }

    func writeExport(_ data: Data, to url: URL) throws {
        try write(data, to: url)
    }

    private func encode(_ image: CGImage, scale: CGFloat, format: ImageFormat) throws -> Data {
        let prepared = ImageScaler.prepare(image, scale: scale, downscale: settings.downscaleRetina)
        return try ImageEncoder.data(
            for: prepared.image,
            format: format,
            quality: settings.imageQuality,
            scale: prepared.scale
        )
    }

    private func renderName(context: FilenameContext) -> String {
        let raw = settings.filenameTemplate
        let counter = FilenameTemplate.usesCounter(raw)
            ? FilenameTemplate.nextCounter()
            : UserDefaults.standard.integer(forKey: FilenameTemplate.counterKey)
        return template.render(template: raw, context: context, counter: counter)
    }

    private func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
            Log.export.info("Saved screenshot (\(data.count) bytes)")
        } catch {
            Log.export.error("Write failed: \(error.localizedDescription, privacy: .public)")
            throw ExportError.writeFailed(path: url.path, reason: error.localizedDescription)
        }
    }

    static func makeNSImage(_ image: CGImage, scale: CGFloat) -> NSImage {
        let safeScale = scale > 0 ? scale : 1
        let size = NSSize(width: CGFloat(image.width) / safeScale, height: CGFloat(image.height) / safeScale)
        return NSImage(cgImage: image, size: size)
    }
}
