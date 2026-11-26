import CoreGraphics
import Foundation
import ShotCore

/// OCR and barcode detection backed by Vision. Work runs off the main actor.
@MainActor
public final class TextRecognizer: TextRecognizing {
    public init() {}

    public func recognizeText(in image: CGImage, languages: [String]) async throws -> String {
        let input = SendableImage(image)
        let text = try await VisionRunner.run {
            try OCREngine.recognize(in: input.image, languages: languages)
        }
        Log.tools.info("OCR finished, \(text.count, privacy: .public) characters recognized")
        return text
    }

    public func detectCodes(in image: CGImage) async throws -> [String] {
        let input = SendableImage(image)
        let payloads = try await VisionRunner.run {
            try BarcodeDetector.detect(in: input.image)
        }
        Log.tools.info("Barcode detection finished, \(payloads.count, privacy: .public) codes found")
        return payloads
    }
}

/// Wraps an immutable CGImage so it can cross isolation boundaries.
struct SendableImage: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Executes synchronous Vision work on a global queue and bridges it to async/await.
enum VisionRunner {
    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try continuation.resume(returning: work())
                } catch {
                    Log.tools.error("Vision request failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
