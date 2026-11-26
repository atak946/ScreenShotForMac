#!/usr/bin/env bash
# Captures README screenshots of the app's own windows, showing only the synthetic demo
# images in scripts/design/demo. Never captures the desktop, the menu bar or real history.
#
# Usage (from the repository root, after building the Debug app):
#   swift scripts/design/make-demo.swift
#   scripts/design/capture-screenshots.sh            # both languages
#   scripts/design/capture-screenshots.sh en         # one language
#
# Requires: the Debug build in DerivedData, swiftc (for the window lister).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/DerivedData/Build/Products/Debug/ScreenShotForMac.app"
BUNDLE_ID="app.screenshotformac.ScreenShotForMac"
WORKFLOWS="$HOME/Library/Application Support/$BUNDLE_ID/Workflows.json"
WORK="$(mktemp -d)"

# The workflow list is seeded in the launch language. Keep the user's file aside while the
# examples are shown, and always put it back.
[[ -f "$WORKFLOWS" ]] && cp -p "$WORKFLOWS" "$WORK/Workflows.json.backup"
cleanup() {
    pkill -f "ScreenShotForMac.app/Contents/MacOS" || true
    if [[ -f "$WORK/Workflows.json.backup" ]]; then
        cp -p "$WORK/Workflows.json.backup" "$WORKFLOWS"
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT
# Copy the demo images out of the repository: folders such as ~/Documents are privacy
# protected, and a file-access prompt would block the app while it opens them.
DEMO="$WORK/demo"
mkdir -p "$DEMO"
cp "$ROOT"/scripts/design/demo/*.png "$DEMO/"

[[ -d "$APP" ]] || { echo "Build the Debug app first: $APP" >&2; exit 1; }

# Tiny window lister: prints "<id> <width> <height>" for on-screen layer-0 windows of a PID.
cat > "$WORK/windows.swift" <<'SWIFT'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1]) ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list where (window[kCGWindowOwnerPID as String] as? Int) == pid
    && (window[kCGWindowLayer as String] as? Int) == 0 {
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let number = window[kCGWindowNumber as String] as? Int ?? 0
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    FileHandle.standardOutput.write(Data("\(number) \(width) \(height)\n".utf8))
}
SWIFT
swiftc -O "$WORK/windows.swift" -o "$WORK/windows" 2>/dev/null

quit_app() {
    pkill -f "ScreenShotForMac.app/Contents/MacOS" || true
    sleep 1
}

launch() { # $1 = language
    quit_app
    open -n "$APP" --args -AppleLanguages "($1)"
    sleep 3
}

# Brings the app forward (Stage Manager shrinks inactive windows) and captures its largest
# on-screen window into $1, keeping the window shadow.
capture_largest() {
    local pid id width attempt
    pid="$(pgrep -f "ScreenShotForMac.app/Contents/MacOS" | head -1)"
    for attempt in 1 2 3 4 5; do
        osascript -e "tell application id \"$BUNDLE_ID\" to activate" >/dev/null
        sleep 2
        read -r width id < <("$WORK/windows" "$pid" | awk '{ print $2 * $3, $2, $1 }' | sort -rn | head -1 | awk '{ print $2, $3 }') || true
        if [[ -n "${id:-}" && "${width:-0}" -gt 400 ]]; then
            screencapture -x -l "$id" "$1"
            sips -Z 1800 "$1" >/dev/null
            echo "  $1"
            return 0
        fi
    done
    echo "No full-size window found for $1" >&2
    return 1
}

settings_shot() { # $1 = language, $2 = pane id, $3 = output name
    quit_app
    defaults write "$BUNDLE_ID" settings.lastSelectedPane "$2"
    launch "$1"
    open "ssfm://settings"
    sleep 2
    capture_largest "$ROOT/docs/images/$1/$3.png"
}

url_shot() { # $1 = language, $2 = ssfm URL, $3 = output name
    launch "$1"
    open "$2"
    sleep 3
    capture_largest "$ROOT/docs/images/$1/$3.png"
}

languages=("${@:-en tr}")
previous_pane="$(defaults read "$BUNDLE_ID" settings.lastSelectedPane 2>/dev/null || echo general)"

for lang in ${languages[*]}; do
    echo "Capturing $lang"
    mkdir -p "$ROOT/docs/images/$lang"
    settings_shot "$lang" general settings-general
    settings_shot "$lang" shortcuts settings-shortcuts
    rm -f "$WORKFLOWS"
    settings_shot "$lang" workflows settings-workflows
    url_shot "$lang" "ssfm://open?path=$DEMO/dashboard.png" editor
    url_shot "$lang" "ssfm://backdrop?path=$DEMO/code.png" backdrop
    url_shot "$lang" "ssfm://combine?path=$DEMO/dashboard.png&path=$DEMO/code.png&path=$DEMO/palette.png" combine
done

quit_app
defaults write "$BUNDLE_ID" settings.lastSelectedPane "$previous_pane"
echo "Done. Relaunch your normal instance with: open \"$APP\""
