import Foundation

public struct GradientPreset: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let spec: GradientSpec
}

/// Curated two-color gradients.
public enum GradientPresets {
    public static let all: [GradientPreset] = [
        GradientPreset(id: "dusk", name: String(localized: "Dusk", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0x6366F1), end: RGBAColor(hex: 0xEC4899), angle: 135
        )),
        GradientPreset(id: "ocean", name: String(localized: "Ocean", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0x0EA5E9), end: RGBAColor(hex: 0x1E3A8A), angle: 160
        )),
        GradientPreset(id: "sunset", name: String(localized: "Sunset", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0xF97316), end: RGBAColor(hex: 0xDB2777), angle: 120
        )),
        GradientPreset(id: "mint", name: String(localized: "Mint", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0x34D399), end: RGBAColor(hex: 0x0F766E), angle: 145
        )),
        GradientPreset(id: "peach", name: String(localized: "Peach", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0xFDE68A), end: RGBAColor(hex: 0xFCA5A5), angle: 110
        )),
        GradientPreset(id: "lavender", name: String(localized: "Lavender", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0xE9D5FF), end: RGBAColor(hex: 0x93C5FD), angle: 135
        )),
        GradientPreset(id: "graphite", name: String(localized: "Graphite", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0x475569), end: RGBAColor(hex: 0x0F172A), angle: 180
        )),
        GradientPreset(id: "aurora", name: String(localized: "Aurora", bundle: .module), spec: GradientSpec(
            start: RGBAColor(hex: 0x22D3EE), end: RGBAColor(hex: 0xA855F7), angle: 45
        )),
    ]
}
