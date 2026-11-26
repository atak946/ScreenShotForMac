import CoreGraphics
import ShotCore
import Vision

/// Rows at the top / bottom that did not move between two frames (sticky header / footer).
struct StaticBands: Sendable, Equatable {
    let header: Int
    let footer: Int

    /// The scrolling rows between the bands for a frame of `height` rows.
    func scrollingRange(height: Int) -> Range<Int> {
        header..<max(header, height - footer)
    }
}

/// A frame plus its precomputed row signatures.
struct StitchFrame: @unchecked Sendable {
    let image: CGImage
    let signatures: RowSignatures
}

enum OffsetEstimate: Sendable, Equatable {
    /// The scrolling region did not move.
    case unchanged
    /// Content moved up by `n` rows (positive = scrolled down, negative = scrolled up).
    case shift(Int)
    /// No reliable overlap was found.
    case noMatch
}

/// Estimates the vertical scroll offset between two frames. Vision first, row-signature search as fallback.
enum OffsetEstimator {
    /// Max total bucket difference for two rows to count as identical.
    private static let identicalRowTolerance = RowSignatures.bucketCount
    /// Max mean per-bucket difference for an overlap to be accepted.
    private static let acceptCost = 4.0
    /// Static bands may cover at most this fraction of the frame.
    private static let maxBandFraction = 0.4
    private static let coarseCandidates = 6
    private static let refineRadius = 2

    // MARK: - Static bands

    /// Detects unchanged rows at the top and bottom. Returns nil when the frames are identical.
    static func staticBands(previous: RowSignatures, current: RowSignatures) -> StaticBands? {
        let height = min(previous.rowCount, current.rowCount)
        var header = 0
        while header < height, isIdentical(previous, current, row: header) { header += 1 }
        guard header < height else { return nil }
        var footer = 0
        while footer < height - header, isIdentical(previous, current, row: height - 1 - footer) { footer += 1 }
        let limit = Int(Double(height) * maxBandFraction)
        return StaticBands(header: min(header, limit), footer: min(footer, limit))
    }

    // MARK: - Offset

    static func estimate(previous: StitchFrame, current: StitchFrame, bands: StaticBands) -> OffsetEstimate {
        let range = bands.scrollingRange(height: current.signatures.rowCount)
        guard range.count >= minimumOverlap(for: range) * 2 else { return .noMatch }
        if let shift = visionShift(previous: previous, current: current, range: range) {
            return shift == 0 ? .unchanged : .shift(shift)
        }
        return searchShift(previous: previous.signatures, current: current.signatures, range: range)
    }

    // MARK: - Vision

    /// Runs translational registration on the scrolling region and verifies the result with row costs.
    private static func visionShift(previous: StitchFrame, current: StitchFrame, range: Range<Int>) -> Int? {
        let width = current.image.width
        let crop = CGRect(x: 0, y: range.lowerBound, width: width, height: range.count)
        guard let reference = previous.image.cropping(to: crop),
              let target = current.image.cropping(to: crop) else { return nil }
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: target, options: [:])
        let handler = VNImageRequestHandler(cgImage: reference, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Log.capture.debug("Vision registration failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let transform = request.results?.first?.alignmentTransform,
              abs(transform.tx) <= 2 else { return nil }
        let magnitude = Int(abs(transform.ty).rounded())
        let candidates = Set([magnitude, -magnitude].flatMap { center in
            (-refineRadius...refineRadius).map { center + $0 }
        })
        return bestVerified(candidates, previous: previous.signatures, current: current.signatures, range: range)
    }

    private static func bestVerified(
        _ candidates: Set<Int>,
        previous: RowSignatures,
        current: RowSignatures,
        range: Range<Int>
    ) -> Int? {
        let scored = candidates.compactMap { shift -> (Int, Double)? in
            fullCost(previous, current, shift: shift, range: range).map { (shift, $0) }
        }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 <= acceptCost else { return nil }
        return best.0
    }

    // MARK: - Row-signature search

    private static func searchShift(previous: RowSignatures, current: RowSignatures, range: Range<Int>) -> OffsetEstimate {
        let maxShift = range.count - minimumOverlap(for: range)
        guard maxShift > 0 else { return .noMatch }
        let coarse = (-maxShift...maxShift).compactMap { shift -> (Int, Double)? in
            coarseCost(previous, current, shift: shift, range: range).map { (shift, $0) }
        }
        let seeds = coarse.sorted { $0.1 < $1.1 }.prefix(coarseCandidates).map(\.0)
        let candidates = Set(seeds.flatMap { seed in (-refineRadius...refineRadius).map { seed + $0 } })
        let refined = candidates.compactMap { shift -> (Int, Double)? in
            fullCost(previous, current, shift: shift, range: range).map { (shift, $0) }
        }.sorted { $0.1 < $1.1 }
        guard let best = refined.first, best.1 <= acceptCost else { return .noMatch }
        if isAmbiguous(best: best, in: refined) {
            Log.capture.debug("Scroll offset ambiguous (repeating content); skipping frame")
            return .noMatch
        }
        return best.0 == 0 ? .unchanged : .shift(best.0)
    }

    /// True when a clearly different shift matches almost as well (repeating patterns).
    private static func isAmbiguous(best: (Int, Double), in scored: [(Int, Double)]) -> Bool {
        scored.contains { candidate in
            abs(candidate.0 - best.0) > refineRadius * 2 && candidate.1 <= best.1 * 1.05 + 0.05
        }
    }

    // MARK: - Costs

    /// Rows `r` of `current` compared with rows `r + shift` of `previous`, both inside `range`.
    private static func overlap(shift: Int, range: Range<Int>) -> Range<Int>? {
        let lower = max(range.lowerBound, range.lowerBound - shift)
        let upper = min(range.upperBound, range.upperBound - shift)
        guard upper - lower >= minimumOverlap(for: range) else { return nil }
        return lower..<upper
    }

    private static func minimumOverlap(for range: Range<Int>) -> Int {
        max(12, range.count / 8)
    }

    private static func coarseCost(_ previous: RowSignatures, _ current: RowSignatures, shift: Int, range: Range<Int>) -> Double? {
        guard let rows = overlap(shift: shift, range: range) else { return nil }
        var total = 0
        var samples = 0
        previous.rowSums.withUnsafeBufferPointer { prev in
            current.rowSums.withUnsafeBufferPointer { cur in
                for row in stride(from: rows.lowerBound, to: rows.upperBound, by: 2) {
                    total += abs(Int(cur[row]) - Int(prev[row + shift]))
                    samples += 1
                }
            }
        }
        guard samples > 0 else { return nil }
        return Double(total) / Double(samples * RowSignatures.bucketCount)
    }

    private static func fullCost(_ previous: RowSignatures, _ current: RowSignatures, shift: Int, range: Range<Int>) -> Double? {
        guard let rows = overlap(shift: shift, range: range) else { return nil }
        let total = rows.reduce(0) { sum, row in
            sum + current.difference(row: row, to: previous, row: row + shift)
        }
        return Double(total) / Double(rows.count * RowSignatures.bucketCount)
    }

    private static func isIdentical(_ previous: RowSignatures, _ current: RowSignatures, row: Int) -> Bool {
        current.difference(row: row, to: previous, row: row) <= identicalRowTolerance
    }
}
