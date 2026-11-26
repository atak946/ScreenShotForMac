import Foundation
import ShotCore

/// Persists non-secret upload settings (Codable JSON in UserDefaults) and secrets (Keychain).
@MainActor
public final class UploadSettingsStore {
    public static let shared = UploadSettingsStore()

    private enum Key {
        static let preferences = "upload.preferences"
        static let s3 = "upload.s3"
        static let customHTTP = "upload.customHTTP"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Non-secret

    public var preferences: UploadPreferences {
        get { load(Key.preferences) ?? UploadPreferences() }
        set { save(newValue, key: Key.preferences) }
    }

    public var s3: S3Configuration {
        get { load(Key.s3) ?? S3Configuration() }
        set { save(newValue, key: Key.s3) }
    }

    public var customHTTP: CustomHTTPConfiguration {
        get { load(Key.customHTTP) ?? CustomHTTPConfiguration() }
        set {
            let previous = customHTTP
            save(Self.strippingSecrets(newValue), key: Key.customHTTP)
            removeOrphanedSecrets(previous: previous, current: newValue)
        }
    }

    // MARK: Secrets

    public var s3SecretAccessKey: String {
        get { UploadKeychain.read(UploadKeychain.s3SecretAccount) }
        set { UploadKeychain.write(newValue, account: UploadKeychain.s3SecretAccount) }
    }

    public func headerSecret(for id: UUID) -> String {
        UploadKeychain.read(UploadKeychain.headerAccount(id))
    }

    public func setHeaderSecret(_ value: String, for id: UUID) {
        UploadKeychain.write(value, account: UploadKeychain.headerAccount(id))
    }

    // MARK: Resolved

    func resolvedS3() -> ResolvedS3Configuration {
        ResolvedS3Configuration(config: s3, secretAccessKey: s3SecretAccessKey)
    }

    func resolvedCustomHTTP() -> ResolvedCustomHTTPConfiguration {
        let config = customHTTP
        let headers = config.headers
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { header in
                (
                    name: header.name.trimmingCharacters(in: .whitespaces),
                    value: header.isSecret ? headerSecret(for: header.id) : header.value
                )
            }
        return ResolvedCustomHTTPConfiguration(config: config, headers: headers)
    }

    // MARK: Private

    private static func strippingSecrets(_ config: CustomHTTPConfiguration) -> CustomHTTPConfiguration {
        var copy = config
        copy.headers = config.headers.map { header in
            var stored = header
            if header.isSecret { stored.value = "" }
            return stored
        }
        return copy
    }

    private func removeOrphanedSecrets(previous: CustomHTTPConfiguration, current: CustomHTTPConfiguration) {
        let secretIDs = Set(current.headers.filter(\.isSecret).map(\.id))
        for header in previous.headers where header.isSecret && !secretIDs.contains(header.id) {
            UploadKeychain.delete(UploadKeychain.headerAccount(header.id))
        }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Log.export.error("Failed to decode upload settings \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func save(_ value: some Encodable, key: String) {
        do {
            try defaults.set(JSONEncoder().encode(value), forKey: key)
        } catch {
            Log.export.error("Failed to encode upload settings \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
