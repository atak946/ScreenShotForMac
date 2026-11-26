import CoreGraphics
import Foundation
import Vision

/// Synchronous Vision barcode detection. Call from a background queue only.
enum BarcodeDetector {
    static func detect(in image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        if let symbologies = try? request.supportedSymbologies(), !symbologies.isEmpty {
            request.symbologies = symbologies
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        return payloads.reduce(into: [String]()) { result, payload in
            if !payload.isEmpty, !result.contains(payload) { result.append(payload) }
        }
    }
}
