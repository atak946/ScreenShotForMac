import Foundation

/// Immutable wall-clock bookkeeping for the elapsed-time display, excluding paused time.
struct RecordingClock: Sendable, Equatable {
    let startedAt: Date
    let pausedTotal: TimeInterval
    let pausedAt: Date?

    init(startedAt: Date = Date(), pausedTotal: TimeInterval = 0, pausedAt: Date? = nil) {
        self.startedAt = startedAt
        self.pausedTotal = pausedTotal
        self.pausedAt = pausedAt
    }

    var isPaused: Bool { pausedAt != nil }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        let reference = pausedAt ?? now
        return max(0, reference.timeIntervalSince(startedAt) - pausedTotal)
    }

    func paused(at now: Date = Date()) -> RecordingClock {
        guard pausedAt == nil else { return self }
        return RecordingClock(startedAt: startedAt, pausedTotal: pausedTotal, pausedAt: now)
    }

    func resumed(at now: Date = Date()) -> RecordingClock {
        guard let pausedAt else { return self }
        return RecordingClock(
            startedAt: startedAt,
            pausedTotal: pausedTotal + now.timeIntervalSince(pausedAt),
            pausedAt: nil
        )
    }
}
