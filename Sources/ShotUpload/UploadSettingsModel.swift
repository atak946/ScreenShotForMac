import AppKit
import Observation
import ShotCore

/// State behind `UploadSettingsPane`; every change is persisted immediately.
@MainActor
@Observable
final class UploadSettingsModel {
    enum TestState: Equatable {
        case idle
        case running
        case succeeded(URL)
        case failed(String)
    }

    var preferences: UploadPreferences { didSet { if preferences != oldValue { store.preferences = preferences } } }
    var s3: S3Configuration { didSet { if s3 != oldValue { store.s3 = s3 } } }
    var customHTTP: CustomHTTPConfiguration { didSet { if customHTTP != oldValue { store.customHTTP = customHTTP } } }
    var s3Secret: String { didSet { if s3Secret != oldValue { store.s3SecretAccessKey = s3Secret } } }
    private(set) var headerSecrets: [UUID: String]
    private(set) var testState: TestState = .idle

    @ObservationIgnored private let store: UploadSettingsStore
    @ObservationIgnored private let service: UploadService
    @ObservationIgnored private var testTask: Task<Void, Never>?

    init(store: UploadSettingsStore = .shared) {
        self.store = store
        service = UploadService(store: store)
        preferences = store.preferences
        s3 = store.s3
        let custom = store.customHTTP
        customHTTP = custom
        s3Secret = store.s3SecretAccessKey
        headerSecrets = Dictionary(
            uniqueKeysWithValues: custom.headers.filter(\.isSecret).map { ($0.id, store.headerSecret(for: $0.id)) }
        )
    }

    // MARK: Headers

    func headerSecret(for id: UUID) -> String {
        headerSecrets[id] ?? ""
    }

    func setHeaderSecret(_ value: String, for id: UUID) {
        headerSecrets[id] = value
        store.setHeaderSecret(value, for: id)
    }

    func addHeader() {
        customHTTP.headers.append(UploadHeader())
    }

    func removeHeader(_ id: UUID) {
        customHTTP.headers.removeAll { $0.id == id }
        headerSecrets[id] = nil
    }

    /// Moves the value between the plain config and the Keychain.
    func setHeaderSecret(isSecret: Bool, for id: UUID) {
        guard let index = customHTTP.headers.firstIndex(where: { $0.id == id }),
              customHTTP.headers[index].isSecret != isSecret else { return }
        var header = customHTTP.headers[index]
        if isSecret {
            setHeaderSecret(header.value, for: id)
            header.value = ""
        } else {
            header.value = headerSecret(for: id)
            setHeaderSecret("", for: id)
        }
        header.isSecret = isSecret
        customHTTP.headers[index] = header
    }

    // MARK: Test

    func runTest() {
        testTask?.cancel()
        testState = .running
        testTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.testConnection()
                testState = .succeeded(result.url)
                Log.export.info("Upload test succeeded")
            } catch {
                testState = .failed(error.localizedDescription)
                Log.export.error("Upload test failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func resetTest() {
        testTask?.cancel()
        testState = .idle
    }

    func copy(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }
}
