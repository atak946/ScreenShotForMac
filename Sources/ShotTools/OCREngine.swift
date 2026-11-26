import CoreGraphics
import Foundation
import Vision

/// Synchronous Vision OCR. Call from a background queue only.
enum OCREngine {
    struct Fragment {
        let text: String
        /// Normalized bounding box, bottom-left origin.
        let box: CGRect
    }

    static func recognize(in image: CGImage, languages: [String]) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let resolved = resolveLanguages(languages, supported: supported)
        if !resolved.isEmpty {
            request.recognitionLanguages = resolved
        }
        request.automaticallyDetectsLanguage = resolved.count != 1

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let fragments = (request.results ?? []).compactMap { observation -> Fragment? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : Fragment(text: text, box: observation.boundingBox)
        }
        return layout(fragments)
    }

    /// Maps requested BCP-47 codes onto languages Vision supports (exact, then by language prefix).
    static func resolveLanguages(_ requested: [String], supported: [String]) -> [String] {
        let matches = requested.compactMap { code -> String? in
            if let exact = supported.first(where: { $0.caseInsensitiveCompare(code) == .orderedSame }) {
                return exact
            }
            let prefix = code.split(separator: "-").first.map { String($0).lowercased() } ?? code.lowercased()
            return supported.first { candidate in
                let lower = candidate.lowercased()
                return lower == prefix || lower.hasPrefix(prefix + "-")
            }
        }
        return matches.reduce(into: [String]()) { result, code in
            if !result.contains(code) { result.append(code) }
        }
    }

    /// Orders fragments top-to-bottom, left-to-right; same visual line joined by spaces.
    static func layout(_ fragments: [Fragment]) -> String {
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        let lines = sorted.reduce(into: [[Fragment]]()) { lines, fragment in
            if let reference = lines.last?.first, isSameLine(reference, fragment) {
                lines[lines.count - 1].append(fragment)
            } else {
                lines.append([fragment])
            }
        }
        return lines
            .map { line in line.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    private static func isSameLine(_ lhs: Fragment, _ rhs: Fragment) -> Bool {
        let overlap = min(lhs.box.maxY, rhs.box.maxY) - max(lhs.box.minY, rhs.box.minY)
        let minHeight = min(lhs.box.height, rhs.box.height)
        return minHeight > 0 && overlap > minHeight * 0.5
    }
}
