@preconcurrency import CoreMedia

enum AudioSource: Sendable, Hashable {
    case system
    case microphone
}

/// Receives captured samples. `append*` is called serially on the capture queue;
/// `finish` / `discard` are called once after the stream stopped and drained.
protocol SampleSink: AnyObject, Sendable {
    func appendVideo(_ buffer: CMSampleBuffer)
    func appendAudio(_ buffer: CMSampleBuffer, source: AudioSource)
    /// Finalizes the file. `endTime` is the stop time on the output timeline.
    /// Returns the recorded duration in seconds.
    func finish(endTime: CMTime) async throws -> TimeInterval
    /// Aborts writing and deletes any partial output.
    func discard()
}
