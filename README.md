<div align="center">

# ScreenShotForMac

**Capture, annotate, record and share. One native, private, open-source toolkit for macOS.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
[![CI](https://github.com/atak946/ScreenShotForMac/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)

</div>

> **Note:** "ScreenShotForMac" is a working title. The final name and icon are not decided yet.

ScreenShotForMac is a menu bar app that puts screenshots, screen recordings, pixel tools and an
annotation editor behind a few global shortcuts. Everything runs on your Mac. There is no
account, no telemetry, and nothing is uploaded unless you set up an upload destination yourself.

---

## Features

Feature status is tracked in [docs/FEATURES.md](docs/FEATURES.md). Items marked *(in progress)*
are being built and may not be in the current build yet.

### Capture
- Area selection with live size, coordinates and a pixel magnifier
- Window capture with hover highlight and optional window shadow, including windows that are behind other windows
- Fullscreen capture of the active display or all displays, with correct handling of mixed-DPI setups
- UI element snapping through the Accessibility API
- Scrolling capture that scrolls for you and stitches the frames
- Capture with a timer, and recapture of the previous area
- Frozen screen during selection, so menus and animations stay still
- An action toolbar on the selection: screenshot, record, scroll, OCR

### Recording
- Video (MP4/MOV) and GIF recording of an area, a window or a full screen
- System audio and microphone, both optional
- Click highlighting and cursor visibility settings
- Pause, resume and cancel, with an elapsed time display
- Basic video editing: trim and mute *(in progress)*

### Editor
- Arrows (single or double headed), lines, rectangles, ellipses, text and a pen with smoothing
- Highlighter, blur, pixelate, spotlight and magnifier callouts
- Smart erase that fills a region with the surrounding background color
- Auto-incrementing step counters
- Image layers, crop with aspect presets, rotate and flip
- Select, move, resize, reorder and copy/paste; full undo and redo
- Zoom, pan and a pixel grid
- One-letter shortcuts for every tool (`A` arrow, `R` rectangle, `T` text, `B` blur, `C` crop, …)
- Combining several images into one *(in progress)*

### Tools
- Color picker with HEX, RGB, HSL, SwiftUI and NSColor output
- Pixel ruler with edge detection, plus point-to-point and area measurement
- On-device text recognition (OCR) with selectable languages
- QR code and barcode scanning
- Backdrop: gradient, solid color or blurred wallpaper backgrounds, with padding, corner radius, shadow and saved presets
- Pinned screenshots that float above other windows, with opacity, click-through, rotation and zoom

### Sharing
- Copy to the clipboard, save as PNG, JPEG or HEIC with a quality setting
- File name templates such as `{date}_{time}_{counter}`
- Optional Retina-to-1x downscaling
- Drag and drop from the Quick Access preview into any app
- Uploads to S3-compatible storage (AWS S3, Cloudflare R2, MinIO) or a custom HTTP endpoint, with credentials kept in the Keychain *(in progress)*

### Automation
- `ssfm://` URL scheme for Raycast, Alfred and Shortcuts
- `ssfm` command-line tool (see [CLI](#cli))
- Per-shortcut workflows (capture, then process, then deliver) and App Intents for Shortcuts.app *(in progress)*
- Configurable after-capture action: Quick Access, editor, clipboard or file

### Privacy
- No analytics, telemetry or crash reporting
- OCR, barcode detection and image processing run on device with Apple's Vision and Core Image frameworks
- History is stored locally, can be searched by its OCR text, and is cleared automatically after a retention period you choose
- Network access is used only for uploads you configure. See [PRIVACY.md](PRIVACY.md).

---

## Keyboard shortcuts

Default global shortcuts. You can change all of them in **Settings → Shortcuts**.

| Shortcut | Action |
|---|---|
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>1</kbd> | Capture area |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>2</kbd> | Capture window |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>3</kbd> | Capture fullscreen |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>4</kbd> | Capture text (OCR) |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>5</kbd> | Pick color |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>6</kbd> | Scan QR code |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>7</kbd> | Record screen (video) |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>8</kbd> | Record screen (GIF) |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>9</kbd> | Scrolling capture |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>0</kbd> | Measure (pixel ruler) |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>R</kbd> | Capture previous area |
| <kbd>⌥</kbd><kbd>⇧</kbd><kbd>V</kbd> | Open clipboard in editor |
| *(unassigned)* | Capture area with timer · Pin image from clipboard · Capture history |

The editor has its own single-key tool shortcuts: `V` select, `A` arrow, `L` line, `R` rectangle,
`O` ellipse, `T` text, `H` highlight, `B` blur, `P` pixelate, `S` spotlight, `M` magnifier,
`E` smart erase, `N` counter, `D` pen, `C` crop.

---

## Automation

### URL scheme

```text
ssfm://capture?mode=area|window|fullscreen|scrolling|last&action=copy|save|edit|upload|pin&delay=N
ssfm://record?format=mp4|gif    # start or stop a recording
ssfm://workflow?name=<name>     # or ?id=<uuid>
ssfm://open?path=<file>         # open an image in the editor
ssfm://ocr                      # capture text
ssfm://color                    # pick a color
ssfm://qr                       # scan a QR code
ssfm://measure                  # pixel ruler
ssfm://history                  # open the history browser
ssfm://settings                 # open Settings
```

`mode` defaults to `area`; without `action` the "after capture" setting is used.
From a terminal: `open "ssfm://capture?mode=window&action=copy"`.

### CLI

The `ssfm` command-line tool (`Sources/ShotCLI`) builds these URLs for you. Install it with:

```sh
scripts/install-cli.sh                 # builds a release binary, installs to /usr/local/bin (uses sudo if needed)
scripts/install-cli.sh --prefix ~/bin  # or any user-writable directory, no sudo
scripts/install-cli.sh --link          # symlink to the build output instead of copying
```

```sh
ssfm capture --copy
ssfm capture window --save --delay 3
ssfm record gif
ssfm workflow "Capture → Upload → Copy link"
ssfm open ~/Desktop/shot.png
ssfm --help
```

The app must be installed (it handles the `ssfm://` URLs); the CLI only forwards commands.

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- Building from source: Xcode 16 or later (Swift 6) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Install

Signed and notarized builds will be published on the [Releases](../../releases) page. Until then,
build from source.

## Build from source

```sh
brew install xcodegen

git clone https://github.com/atak946/ScreenShotForMac.git
cd ScreenShotForMac

# Signing: put your Apple Developer Team ID in a local, gitignored config
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit Config/Local.xcconfig -> DEVELOPMENT_TEAM = <your team id>

xcodegen generate
open ScreenShotForMac.xcodeproj     # or build from the command line:

xcodebuild -project ScreenShotForMac.xcodeproj \
  -scheme ScreenShotForMac -configuration Debug \
  -derivedDataPath DerivedData build
```

To build without a signing identity (for CI or a quick compile check), add
`CODE_SIGNING_ALLOWED=NO`. An unsigned build cannot keep the Screen Recording permission between
launches, so use a signed build for day-to-day testing.

The `ShotKit` Swift package compiles and tests on its own:

```sh
swift build
swift test
```

The `.xcodeproj` is generated. Change `project.yml`, not the project file.

---

## Permissions

| Permission | Why it is needed | When it is requested |
|---|---|---|
| **Screen Recording** | Required by macOS to read screen pixels for screenshots, recordings, OCR, color picking and measuring. | On first launch, during onboarding |
| **Accessibility** | UI element snapping, automatic scrolling for scrolling capture, and click highlighting during recordings. | When you first use a feature that needs it |
| **Microphone** | Recording your voice with a screen recording. | Only when you turn on microphone recording |

You can review and change these in **System Settings → Privacy & Security** or in the app's
**Settings → Permissions** tab. The app is not sandboxed, because the App Sandbox blocks the
Accessibility and event-tap features listed above. It is distributed with Developer ID signing,
the hardened runtime and notarization.

---

## Localization

The app ships in **English** and **Turkish**. Strings live in String Catalogs
(`Localizable.xcstrings`): one in each module's `Resources/` folder and one in `App/Resources/`.

To add a language:

1. Open the project in Xcode, select any `Localizable.xcstrings` file, and add the language with
   the **+** button. Repeat for every module's catalog.
2. Translate the entries. Xcode marks missing translations as you go.
3. Add the language code to `CFBundleLocalizations` in `project.yml`.
4. Add a case to `AppLanguage` in `Sources/ShotCore/AppSettings.swift` so it appears in the
   in-app language picker.
5. Run `xcodegen generate` and check the UI for clipped text.

See [CONTRIBUTING.md](CONTRIBUTING.md#localization) for the localization rules that apply to code.

---

## Architecture

The app target (`App/`) is a thin shell: app delegate, menu bar, URL routing and a coordinator
that connects modules. Features live in the `ShotKit` Swift package. Every feature module
depends only on `ShotCore`, and modules communicate through protocols defined there.

| Module | Responsibility |
|---|---|
| `ShotCore` | Shared models, `AppCommand`, settings, logging, service protocols, design tokens |
| `ShotCapture` | Area, window and fullscreen capture, selection overlay, magnifier, element snapping |
| `ShotRecording` | Screen recording to video and GIF, audio, click highlighting, recording controls |
| `ShotScrolling` | Scrolling capture: auto-scroll, frame grabbing, offset estimation, stitching |
| `ShotEditor` | Annotation editor: canvas, tools, rendering, undo, crop and transform |
| `ShotTools` | OCR, color picker, barcode and QR detection |
| `ShotMeasure` | Pixel ruler and edge-detecting measurement overlay |
| `ShotBackdrop` | Backgrounds, padding, shadows and style presets |
| `ShotPin` | Floating pinned images |
| `ShotExport` | Encoding, saving, file name templates, Quick Access preview, drag export |
| `ShotHistory` | Capture history, thumbnails, OCR search, retention |
| `ShotUpload` | Upload destinations (S3-compatible, custom HTTP), Keychain storage |
| `ShotWorkflow` | Per-shortcut workflows and App Intents |
| `ShotVideoEditor` | Trimming and simple edits for recordings |
| `ShotCombine` | Combining multiple images |
| `ShotSettings` | Settings window, onboarding, global hotkeys, launch at login |
| `ShotCLI` | The `ssfm` command-line tool |

---

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull
request. Release maintainers should read [docs/RELEASING.md](docs/RELEASING.md).

## License

ScreenShotForMac is released under the [MIT License](LICENSE).

Third-party dependency: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).
