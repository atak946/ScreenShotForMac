import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ShotCore
import UniformTypeIdentifiers

/// Steps that talk to other apps: open with, Shortcuts, sound.
enum ExternalActions {
    static let shortcutsToolPath = "/usr/bin/shortcuts"
    static let completionSoundName = "Glass"

    @MainActor
    static func open(_ file: URL, withBundleID bundleID: String) async throws {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed)
        else { throw WorkflowError.appNotFound(trimmed) }
        _ = try await NSWorkspace.shared.open([file], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// `shortcuts run <name> --input-path <file>`; throws on non-zero exit.
    static func runShortcut(named name: String, input: URL) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WorkflowError.shortcutNameMissing }
        let status = try await runProcess(shortcutsToolPath, arguments: ["run", trimmed, "--input-path", input.path])
        guard status == 0 else { throw WorkflowError.shortcutFailed(name: trimmed, status: status) }
    }

    @MainActor
    static func playCompletionSound() {
        NSSound(named: NSSound.Name(completionSoundName))?.play()
    }

    private static func runProcess(_ path: String, arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Writes the current image as PNG into a per-run temporary folder.
enum TemporaryImageFile {
    static func write(_ capture: CaptureResult) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Workflows", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Screenshot-\(UUID().uuidString.prefix(8)).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw WorkflowError.imageEncodingFailed
        }
        let dpi = 72 * capture.scale
        let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, capture.image, properties)
        guard CGImageDestinationFinalize(destination) else { throw WorkflowError.imageEncodingFailed }
        return url
    }
}

/// Resamples a Retina image down to 1 pixel per point.
enum ImageDownscaler {
    static func downscaleTo1x(_ image: CGImage, scale: CGFloat) -> CGImage {
        guard scale > 1 else { return image }
        let width = max(1, Int((CGFloat(image.width) / scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) / scale).rounded()))
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
