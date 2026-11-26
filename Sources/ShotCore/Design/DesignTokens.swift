import AppKit
import SwiftUI

/// Design system for the whole app.
///
/// Direction: native macOS (Tahoe) — Liquid Glass surfaces on macOS 26+, vibrant HUD
/// material on older systems. Compact, quiet chrome; the screenshot is the hero.
/// Accent = system accent color (user's choice). Red is reserved for recording / destructive.
/// Every floating surface (HUD, Quick Access, recording controls, overlay toolbars,
/// editor inspector) uses `GlassSurface` so they look like one family.
public enum DS {
    // MARK: Spacing (4pt grid)

    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    // MARK: Corner radii

    public enum Radius {
        /// Icon buttons, chips.
        public static let control: CGFloat = 7
        /// Cards, thumbnails, text fields.
        public static let card: CGFloat = 10
        /// Floating panels (HUD, toolbars, Quick Access).
        public static let panel: CGFloat = 16
        /// Large floating windows / sheets.
        public static let window: CGFloat = 20
        /// Capsule height-based pills use `height / 2`.
    }

    // MARK: Sizes

    public enum Size {
        public static let iconButton: CGFloat = 28
        public static let iconButtonLarge: CGFloat = 34
        public static let toolbarHeight: CGFloat = 44
        public static let symbolPointSize: CGFloat = 14
        public static let hairline: CGFloat = 0.5
    }

    // MARK: Motion

    public enum Motion {
        public static let fast: TimeInterval = 0.15
        public static let normal: TimeInterval = 0.25
        public static let slow: TimeInterval = 0.4
        public static var spring: Animation { Animation.spring(response: 0.32, dampingFraction: 0.82) }
        public static var easeOut: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1) }
    }

    // MARK: Semantic colors (AppKit)

    public enum Palette {
        public static var accent: NSColor { .controlAccentColor }
        public static var recording: NSColor { NSColor.systemRed }
        public static var success: NSColor { NSColor.systemGreen }
        public static var warning: NSColor { NSColor.systemOrange }
        /// Hairline border drawn on top of glass surfaces.
        public static var surfaceStroke: NSColor { NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.12)
                : NSColor.black.withAlphaComponent(0.10)
        } }
        /// Dim color behind capture overlays outside the selection.
        public static var overlayDim: NSColor { NSColor.black.withAlphaComponent(0.45) }
        /// Neutral canvas around images in the editor / backdrop / pin.
        public static var canvas: NSColor { NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.11, alpha: 1)
                : NSColor(calibratedWhite: 0.93, alpha: 1)
        } }
        /// Selection outline / handles on capture overlays (always readable on any content).
        public static var selection: NSColor { NSColor.white }
        public static var selectionShadow: NSColor { NSColor.black.withAlphaComponent(0.5) }
    }

    // MARK: Typography

    public enum Font {
        public static var hudTitle: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
        public static var hudBody: NSFont { NSFont.systemFont(ofSize: 12, weight: .regular) }
        public static var label: NSFont { NSFont.systemFont(ofSize: 12, weight: .medium) }
        /// Sizes, coordinates, timers: tabular digits so numbers don't jitter.
        public static var numeric: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium) }
        public static var numericLarge: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold) }
        public static var countdown: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 96, weight: .bold) }
    }

    // MARK: Shadows (for panels without system window shadow)

    public enum Shadow {
        public static func apply(to layer: CALayer?, radius: CGFloat = 18, opacity: Float = 0.25) {
            guard let layer else { return }
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = opacity
            layer.shadowRadius = radius
            layer.shadowOffset = CGSize(width: 0, height: -6)
        }
    }
}

extension Color {
    public static var dsRecording: Color { Color(nsColor: DS.Palette.recording) }
    public static var dsCanvas: Color { Color(nsColor: DS.Palette.canvas) }
    public static var dsStroke: Color { Color(nsColor: DS.Palette.surfaceStroke) }
}
