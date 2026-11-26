import Foundation
import ShotCore

/// A user-saved backdrop style.
public struct BackdropNamedPreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var style: BackdropStyle

    public init(id: UUID = UUID(), name: String, style: BackdropStyle) {
        self.id = id
        self.name = name
        self.style = style
    }
}

/// Persists named presets and the last used style in UserDefaults.
@MainActor
public final class BackdropPresetStore {
    public static var defaultPresetName: String { String(localized: "Default", bundle: .module) }
    private static let maxNameLength = 60

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public private(set) var presets: [BackdropNamedPreset]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        presets = []
        presets = decode([BackdropNamedPreset].self, key: Keys.presets) ?? []
    }

    /// Last style used in the composer, or the built-in default.
    public var lastUsedStyle: BackdropStyle {
        decode(BackdropStyle.self, key: Keys.lastUsed)?.sanitized() ?? .standard
    }

    public func rememberLastUsed(_ style: BackdropStyle) {
        encode(style, key: Keys.lastUsed)
    }

    /// Saves (or overwrites by name) a preset. Returns the stored preset, or nil for an empty name.
    @discardableResult
    public func save(name: String, style: BackdropStyle) -> BackdropNamedPreset? {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        guard !trimmed.isEmpty, trimmed != Self.defaultPresetName else { return nil }
        let existing = presets.first { $0.name == trimmed }
        let preset = BackdropNamedPreset(id: existing?.id ?? UUID(), name: trimmed, style: style)
        presets = presets.filter { $0.name != trimmed } + [preset]
        encode(presets, key: Keys.presets)
        return preset
    }

    public func delete(id: UUID) {
        presets = presets.filter { $0.id != id }
        encode(presets, key: Keys.presets)
    }

    // MARK: Private

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Log.editor.error("Failed to decode backdrop data for \(key): \(error.localizedDescription)")
            return nil
        }
    }

    private func encode(_ value: some Encodable, key: String) {
        do {
            try defaults.set(encoder.encode(value), forKey: key)
        } catch {
            Log.editor.error("Failed to encode backdrop data for \(key): \(error.localizedDescription)")
        }
    }

    private enum Keys {
        static let presets = "backdrop.presets"
        static let lastUsed = "backdrop.lastUsedStyle"
    }
}
