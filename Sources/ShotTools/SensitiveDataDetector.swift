import CoreGraphics
import Foundation
import ShotCore
import Vision

/// Finds e-mails, phone numbers, cards, IBANs, IPs, URLs, API keys and JWTs in an image.
/// Vision OCR and matching run on a background queue; results are image pixel rects
/// (top-left origin) padded by `padding`.
@MainActor
public final class SensitiveDataDetector: SensitiveDataDetecting {
    public init() {}

    public func detect(in image: CGImage, kinds: Set<SensitiveKind>) async throws -> [SensitiveRegion] {
        guard !kinds.isEmpty else { return [] }
        let input = SendableImage(image)
        let regions = try await VisionRunner.run {
            try SensitiveScan.run(on: input.image, kinds: kinds)
        }
        Log.tools.info("Sensitive data scan found \(regions.count, privacy: .public) regions")
        return regions
    }
}

/// Synchronous OCR + pattern pass. Call from a background queue only.
enum SensitiveScan {
    static let padding: CGFloat = 2
    private static let candidateCount = 1

    static func run(on image: CGImage, kinds: Set<SensitiveKind>) throws -> [SensitiveRegion] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction "fixes" tokens, keys and numbers into words.
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let patterns = SensitivePatterns(kinds: kinds)
        let size = CGSize(width: image.width, height: image.height)
        return (request.results ?? []).flatMap { observation in
            regions(in: observation, patterns: patterns, imageSize: size)
        }
    }

    private static func regions(
        in observation: VNRecognizedTextObservation,
        patterns: SensitivePatterns,
        imageSize: CGSize
    ) -> [SensitiveRegion] {
        guard let candidate = observation.topCandidates(candidateCount).first else { return [] }
        let text = candidate.string
        return patterns.matches(in: text).compactMap { match in
            let normalized = (try? candidate.boundingBox(for: match.range))?.boundingBox ?? observation.boundingBox
            let rect = pixelRect(fromNormalized: normalized, imageSize: imageSize)
            guard !rect.isEmpty else { return nil }
            return SensitiveRegion(kind: match.kind, pixelRect: rect, text: String(text[match.range]))
        }
    }

    /// Normalized (bottom-left origin) → pixel (top-left origin), padded and clamped.
    static func pixelRect(fromNormalized box: CGRect, imageSize: CGSize) -> CGRect {
        let rect = CGRect(
            x: box.minX * imageSize.width,
            y: (1 - box.maxY) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
        let padded = rect.insetBy(dx: -padding, dy: -padding).integral
        return padded.intersection(CGRect(origin: .zero, size: imageSize))
    }
}
