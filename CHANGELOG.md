# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-26

### Added

#### Capture
- Area capture with live dimensions, coordinates and a pixel magnifier.
- Window capture with hover highlight and an optional window shadow, including windows behind other windows.
- Fullscreen capture for the active display or all displays, with multi-monitor and mixed-DPI support.
- UI element snapping through the Accessibility API.
- Scrolling capture with automatic scrolling and frame stitching.
- Capture with a timer and a countdown, and recapture of the previous area.
- Frozen screen during selection.
- Action toolbar on the selection overlay.

#### Recording
- Video and GIF screen recording of an area, a window or a full screen.
- Optional system audio and microphone audio.
- Click highlighting and cursor visibility options.
- Pause, resume and cancel controls with an elapsed time display.

#### Editor
- Annotation tools: arrow (single or double headed), line, rectangle, ellipse, text, highlighter, pen, blur, pixelate, spotlight, magnifier, smart erase, step counter and image layers.
- Crop with aspect presets, rotate and flip.
- Selection, moving, resizing, layer ordering, copy/paste, and undo/redo.
- Zoom, pan and pixel grid.
- Single-letter tool shortcuts.

#### Tools
- Color picker with HEX, RGB, HSL, SwiftUI and NSColor formats.
- Pixel ruler with edge detection, and point and area measurement.
- On-device OCR with selectable recognition languages.
- QR code and barcode scanning.
- Backdrop backgrounds (gradient, solid, blurred wallpaper) with padding, corner radius, shadow and saved presets.
- Pinned floating screenshots with opacity, click-through, rotation and zoom.

#### Output and history
- Copy to clipboard, and save as PNG, JPEG or HEIC with a quality setting.
- File name templates and optional Retina-to-1x downscaling.
- Quick Access preview with copy, save, edit, pin and drag-and-drop.
- Capture history with a menu bar submenu, OCR text search and automatic retention cleanup.

#### App
- Menu bar app with customizable global shortcuts.
- Permission onboarding for Screen Recording, Accessibility and Microphone.
- Settings for general, shortcuts, output, recording, tools, history and permissions.
- Launch at login.
- `ssfm://` URL scheme for capture, OCR, color picking, QR scanning and settings.
- English and Turkish localization, with an in-app language picker.

#### Sharing and automation
- Uploads to S3-compatible storage (AWS S3, Cloudflare R2, MinIO, B2) and custom HTTP endpoints, with credentials in the Keychain.
- Workflows with per-workflow global shortcuts, `ssfm://` URL automation and Shortcuts.app actions.
- `ssfm` command-line tool (`scripts/install-cli.sh`).
- Video trimming editor and image combine/split tool.
- Automatic updates via Sparkle, published through GitHub Releases.
- English and Turkish localization.

[Unreleased]: https://github.com/atak946/ScreenShotForMac/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/atak946/ScreenShotForMac/releases/tag/v0.1.0
