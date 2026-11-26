import CoreGraphics
import Foundation
import Observation
import ShotCore

/// Persistent capture history in `~/Library/Application Support/ScreenShotForMac/History/`.
///
/// Layout: `<uuid>.png` (lossless original) or the copied recording, `<uuid>.thumb.jpg`
/// (≤ 400 px) and one `index.json`. Originals and thumbnails are encoded in the background;
/// until then `loadCapture` serves the in-memory capture and `pendingThumbnailIDs` contains the id.
///
/// When `AppSettings.historyEnabled` is false, `add` / `addRecording` return a
/// non-persisted item (nothing is written, `loadCapture` returns nil for it) and log the skip.
@MainActor
@Observable
public final class HistoryStore: HistoryStoring {
    /// Newest first.
    public private(set) var items: [HistoryItem] = []
    /// Items whose thumbnail file is still being generated.
    public private(set) var pendingThumbnailIDs: Set<UUID> = []
    /// Called after every change to `items` (in addition to Observation).
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?
    @ObservationIgnored public let rootURL: URL

    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored private var records: [HistoryRecord] = [] {
        didSet { items = records.map { $0.item(root: rootURL) } }
    }

    @ObservationIgnored private var pendingCaptures: [UUID: CaptureResult] = [:]
    @ObservationIgnored private let ocrIndexer = HistoryOCRIndexer()
    @ObservationIgnored private var ocrQueue: [UUID] = []
    @ObservationIgnored private var ocrWorker: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private static let saveDebounce: Duration = .seconds(2)

    public static var defaultRootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ScreenShotForMac/History", isDirectory: true)
    }

    public init(settings: AppSettings = .shared, rootURL: URL? = nil) {
        self.settings = settings
        self.rootURL = rootURL ?? Self.defaultRootURL
        do {
            try ensureDirectory()
        } catch {
            Log.export.error("\(error.localizedDescription, privacy: .public)")
        }
        records = HistoryIndexFile.load(from: self.rootURL).sorted { $0.createdAt > $1.createdAt }
        // Property observers do not fire for assignments inside init.
        items = records.map { $0.item(root: self.rootURL) }
        pruneExpired()
        removeOrphanFiles()
        scheduleDailyPrune()
        enqueueOCR(records.filter { $0.kind == .image && $0.recognizedText == nil }.map(\.id))
    }

    // MARK: - HistoryStoring

    @discardableResult
    public func add(_ capture: CaptureResult) throws -> HistoryItem {
        let id = UUID()
        let record = HistoryRecord(
            id: id, createdAt: capture.capturedAt,
            fileName: "\(id.uuidString).png", thumbnailName: Self.thumbnailName(for: id),
            pixelWidth: Double(capture.image.width), pixelHeight: Double(capture.image.height),
            scale: Double(capture.scale), sourceAppName: capture.sourceAppName, kind: .image,
            mode: capture.mode, screenRect: capture.screenRect, recognizedText: nil
        )
        guard settings.historyEnabled else {
            Log.export.info("History disabled; capture not persisted")
            return record.item(root: rootURL)
        }
        try ensureDirectory()
        pendingCaptures[id] = capture
        insert(record)
        writeCaptureFiles(capture, record: record)
        return record.item(root: rootURL)
    }

    @discardableResult
    public func addRecording(_ recording: RecordingResult) throws -> HistoryItem {
        let id = UUID()
        let kind: HistoryItem.Kind = recording.format == .gif ? .gif : .video
        let sourceExtension = recording.fileURL.pathExtension
        let fileExtension = sourceExtension.isEmpty ? (kind == .gif ? "gif" : "mp4") : sourceExtension
        let record = HistoryRecord(
            id: id, createdAt: Date(),
            fileName: "\(id.uuidString).\(fileExtension)", thumbnailName: Self.thumbnailName(for: id),
            pixelWidth: Double(recording.pixelSize.width), pixelHeight: Double(recording.pixelSize.height),
            scale: 1, sourceAppName: nil, kind: kind, mode: nil, screenRect: nil, recognizedText: nil
        )
        guard settings.historyEnabled else {
            Log.export.info("History disabled; recording not persisted")
            return record.item(root: rootURL)
        }
        try ensureDirectory()
        let destination = fileURL(record.fileName)
        try FileManager.default.copyItem(at: recording.fileURL, to: destination)
        insert(record)
        writeRecordingThumbnail(source: destination, record: record)
        return record.item(root: rootURL)
    }

    public func recentItems(limit: Int) -> [HistoryItem] {
        Array(items.prefix(max(0, limit)))
    }

    public func loadCapture(_ item: HistoryItem) -> CaptureResult? {
        if let pending = pendingCaptures[item.id] { return pending }
        guard let record = records.first(where: { $0.id == item.id }), record.kind == .image else { return nil }
        guard let image = HistoryFileWriter.loadImage(at: fileURL(record.fileName)) else {
            Log.export.error("History image missing for \(record.id.uuidString, privacy: .public)")
            return nil
        }
        let scale = CGFloat(max(record.scale, 1))
        let pointSize = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return CaptureResult(
            image: image, scale: scale,
            screenRect: record.screenRect ?? CGRect(origin: .zero, size: pointSize),
            mode: record.mode ?? .area, capturedAt: record.createdAt, sourceAppName: record.sourceAppName
        )
    }

    public func remove(_ item: HistoryItem) throws {
        try delete(records.filter { $0.id == item.id })
    }

    public func removeAll() throws {
        let orphans = HistoryRetention.orphanFiles(in: rootURL, referenced: referencedFileNames())
        try delete(records)
        for url in orphans { try HistoryRetention.deleteFile(url, root: rootURL) }
    }

    // MARK: - Mutation helpers

    private func insert(_ record: HistoryRecord) {
        pendingThumbnailIDs.insert(record.id)
        records.insert(record, at: 0)
        persistNow()
    }

    /// Drops the records from the index, then deletes their files (inside the root only).
    private func delete(_ doomed: [HistoryRecord]) throws {
        guard !doomed.isEmpty else { return }
        let ids = Set(doomed.map(\.id))
        records.removeAll { ids.contains($0.id) }
        ids.forEach { pendingCaptures[$0] = nil }
        pendingThumbnailIDs.subtract(ids)
        persistNow()
        var firstError: Error?
        for name in doomed.flatMap(\.ownedFileNames) {
            do {
                try HistoryRetention.deleteFile(fileURL(name), root: rootURL)
            } catch {
                Log.export.error("History delete failed: \(error.localizedDescription, privacy: .public)")
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    private func writeCaptureFiles(_ capture: CaptureResult, record: HistoryRecord) {
        let original = fileURL(record.fileName)
        let thumbnail = fileURL(record.thumbnailName)
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { () -> Result<Void, Error> in
                Result {
                    try HistoryFileWriter.writeThumbnail(of: capture.image, to: thumbnail)
                    try HistoryFileWriter.writePNG(capture.image, scale: capture.scale, to: original)
                }
            }.value
            self?.finishBackgroundWrite(record, result: result, isRecording: false)
        }
    }

    private func writeRecordingThumbnail(source: URL, record: HistoryRecord) {
        let thumbnail = fileURL(record.thumbnailName)
        let kind = record.kind
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { () -> Result<Void, Error> in
                do {
                    try await HistoryFileWriter.writeMediaThumbnail(source: source, kind: kind, to: thumbnail)
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }.value
            self?.finishBackgroundWrite(record, result: result, isRecording: true)
        }
    }

    private func finishBackgroundWrite(_ record: HistoryRecord, result: Result<Void, Error>, isRecording: Bool) {
        pendingCaptures[record.id] = nil
        pendingThumbnailIDs.remove(record.id)
        let stillListed = records.contains { $0.id == record.id }
        switch result {
        case .success where !stillListed:
            // Removed while encoding: clean up what was just written.
            record.ownedFileNames.forEach { try? HistoryRetention.deleteFile(fileURL($0), root: rootURL) }
        case .success:
            if record.kind == .image { enqueueOCR([record.id]) }
            notifyChange()
        case let .failure(error):
            Log.export.error("History write failed: \(error.localizedDescription, privacy: .public)")
            // A recording without thumbnail is still useful; a capture without original is not.
            if !isRecording, stillListed { try? delete([record]) } else { notifyChange() }
        }
    }

    // MARK: - OCR

    private func enqueueOCR(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        ocrQueue.append(contentsOf: ids)
        guard ocrWorker == nil else { return }
        ocrWorker = Task { [weak self] in await self?.drainOCRQueue() }
    }

    private func drainOCRQueue() async {
        while !ocrQueue.isEmpty {
            let id = ocrQueue.removeFirst()
            guard pendingCaptures[id] == nil,
                  let record = records.first(where: { $0.id == id }),
                  record.kind == .image, record.recognizedText == nil else { continue }
            let text = await ocrIndexer.recognizeText(
                inImageAt: fileURL(record.fileName), languages: settings.ocrLanguages
            )
            guard let text, let index = records.firstIndex(where: { $0.id == id }) else { continue }
            records[index] = records[index].withRecognizedText(text)
            scheduleSave()
        }
        ocrWorker = nil
    }

    // MARK: - Retention

    private func pruneExpired() {
        let expired = HistoryRetention.expired(records, retentionDays: settings.historyRetentionDays)
        guard !expired.isEmpty else { return }
        Log.export.info("Pruning \(expired.count) expired history items")
        do {
            try delete(expired)
        } catch {
            Log.export.error("History prune incomplete: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeOrphanFiles() {
        for url in HistoryRetention.orphanFiles(in: rootURL, referenced: referencedFileNames()) {
            do {
                try HistoryRetention.deleteFile(url, root: rootURL)
            } catch {
                Log.export.error("Orphan cleanup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func scheduleDailyPrune() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HistoryRetention.checkInterval)
                guard let self else { return }
                pruneExpired()
            }
        }
    }

    // MARK: - Persistence

    private func persistNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try HistoryIndexFile.save(records, to: rootURL)
        } catch {
            Log.export.error("History index save failed: \(error.localizedDescription, privacy: .public)")
        }
        notifyChange()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDebounce)
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    private func notifyChange() {
        onChange?()
    }

    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            throw HistoryError.directoryUnavailable(rootURL.path)
        }
    }

    private func referencedFileNames() -> Set<String> {
        Set(records.flatMap(\.ownedFileNames))
    }

    private func fileURL(_ name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: false)
    }

    private static func thumbnailName(for id: UUID) -> String {
        "\(id.uuidString).thumb.jpg"
    }
}
