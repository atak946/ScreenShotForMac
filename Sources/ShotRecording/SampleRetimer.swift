@preconcurrency import CoreMedia
import os
import ShotCore

/// Implements pause / resume by dropping samples while paused and shifting later
/// timestamps back by the accumulated paused time. Thread-safe.
final class SampleRetimer: Sendable {
    private struct State: Sendable {
        var isPaused = false
        var pauseStartedAt: CMTime = .invalid
        var offset: CMTime = .zero
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Current time of the host clock, which ScreenCaptureKit stamps samples with.
    static func hostNow() -> CMTime {
        CMClockGetTime(CMClockGetHostTimeClock())
    }

    func pause() {
        let now = Self.hostNow()
        state.withLock { state in
            guard !state.isPaused else { return }
            state.isPaused = true
            state.pauseStartedAt = now
        }
    }

    func resume() {
        let now = Self.hostNow()
        state.withLock { state in
            guard state.isPaused else { return }
            state.offset = CMTimeAdd(state.offset, CMTimeSubtract(now, state.pauseStartedAt))
            state.isPaused = false
        }
    }

    /// The current host time mapped onto the output timeline.
    func adjustedNow() -> CMTime {
        let now = Self.hostNow()
        return state.withLock { state in
            let reference = state.isPaused ? state.pauseStartedAt : now
            return CMTimeSubtract(reference, state.offset)
        }
    }

    /// Returns the sample shifted onto the output timeline, or nil when it must be dropped.
    func retime(_ buffer: CMSampleBuffer) -> CMSampleBuffer? {
        let offset: CMTime? = state.withLock { $0.isPaused ? nil : $0.offset }
        guard let offset else { return nil }
        guard CMTimeCompare(offset, .zero) != 0 else { return buffer }
        do {
            let timings = try buffer.sampleTimingInfos().map { info in
                CMSampleTimingInfo(
                    duration: info.duration,
                    presentationTimeStamp: CMTimeSubtract(info.presentationTimeStamp, offset),
                    decodeTimeStamp: info.decodeTimeStamp.isValid
                        ? CMTimeSubtract(info.decodeTimeStamp, offset)
                        : .invalid
                )
            }
            return try CMSampleBuffer(copying: buffer, withNewTiming: timings)
        } catch {
            Log.recording.error("Failed to retime sample: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
