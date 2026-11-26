import Foundation
import Security
import ShotCore

/// Generic-password Keychain storage for upload secrets.
enum UploadKeychain {
    static let service = "app.screenshotformac.upload"

    static let s3SecretAccount = "s3.secretAccessKey"

    static func headerAccount(_ id: UUID) -> String {
        "header.\(id.uuidString)"
    }

    /// Reads a secret; returns an empty string when missing.
    static func read(_ account: String) -> String {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                Log.export.error("Keychain read failed (\(status, privacy: .public))")
            }
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// Stores a secret; an empty value deletes the item.
    static func write(_ value: String, account: String) {
        guard !value.isEmpty else {
            delete(account)
            return
        }
        let data = Data(value.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery(account)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Log.export.error("Keychain add failed (\(addStatus, privacy: .public))")
            }
        } else if status != errSecSuccess {
            Log.export.error("Keychain update failed (\(status, privacy: .public))")
        }
    }

    static func delete(_ account: String) {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            Log.export.error("Keychain delete failed (\(status, privacy: .public))")
        }
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
