import CoreGraphics
import Foundation
import ShotCore
import Vision

/// Background OCR for history items. Being an actor with a synchronous body,
/// recognition jobs run one at a time and never block the main thread.
actor HistoryOCRIndexer {
    /// Recognizes text in the image file. Returns "" when the image has no text,
    /// nil when recognition failed (so it can be retried later).
    func recognizeText(inImageAt url: URL, languages: [String]) -> String? {
        guard let image = HistoryFileWriter.loadImage(at: url) else {
            Log.export.error("History OCR could not read \(url.lastPathComponent, privacy: .public)")
            return nil
        }
        do {
            return try Self.recognize(image, languages: languages)
        } catch {
            Log.export.error("History OCR failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func recognize(_ image: CGImage, languages: [String]) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let resolved = resolveLanguages(languages, supported: supported)
        if !resolved.isEmpty {
            request.recognitionLanguages = resolved
        }
        request.automaticallyDetectsLanguage = resolved.count != 1
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Maps requested BCP-47 codes onto supported Vision languages (exact, then language prefix).
    private static func resolveLanguages(_ requested: [String], supported: [String]) -> [String] {
        let matches = requested.compactMap { code -> String? in
            if let exact = supported.first(where: { $0.caseInsensitiveCompare(code) == .orderedSame }) {
                return exact
            }
            let prefix = code.split(separator: "-").first.map { $0.lowercased() } ?? code.lowercased()
            return supported.first { $0.lowercased() == prefix || $0.lowercased().hasPrefix(prefix + "-") }
        }
        return matches.reduce(into: [String]()) { result, code in
            if !result.contains(code) { result.append(code) }
        }
    }
}
