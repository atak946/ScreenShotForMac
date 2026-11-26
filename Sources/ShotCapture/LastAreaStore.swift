import CoreGraphics
import Foundation
import ShotCore

/// The most recent area selection, persisted so "Capture Last Area" survives relaunches.
struct LastArea: Codable, Sendable {
    /// Global AppKit points.
    let rect: CGRect
    let displayID: CGDirectDisplayID
}

/// UserDefaults persistence for `LastArea`.
struct LastAreaStore {
    private static let key = "ShotCapture.lastArea"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LastArea? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(LastArea.self, from: data)
        } catch {
            Log.capture.error("Discarding unreadable last area: \(error.localizedDescription, privacy: .public)")
            defaults.removeObject(forKey: Self.key)
            return nil
        }
    }

    func save(_ area: LastArea) {
        do {
            try defaults.set(JSONEncoder().encode(area), forKey: Self.key)
        } catch {
            Log.capture.error("Failed to store last area: \(error.localizedDescription, privacy: .public)")
        }
    }
}
