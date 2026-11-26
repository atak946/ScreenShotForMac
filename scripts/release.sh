#!/usr/bin/env bash
#
# Build, sign, package, notarize and staple a ScreenShotForMac release.
#
# Signing details come from environment variables and are never stored in the repo:
#   DEVELOPER_ID_APPLICATION  Full signing identity, e.g. "Developer ID Application: Example Inc (ABCDE12345)"
#   DEVELOPMENT_TEAM          Apple Developer Team ID, e.g. ABCDE12345
#   NOTARY_PROFILE            notarytool keychain profile name (see docs/RELEASING.md)
#
# Run `scripts/release.sh --help` for options.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly APP_NAME="ScreenShotForMac"
readonly SCHEME="ScreenShotForMac"
readonly PROJECT="${ROOT_DIR}/${APP_NAME}.xcodeproj"
readonly PROJECT_SPEC="${ROOT_DIR}/project.yml"

DRY_RUN=0
SKIP_NOTARIZE=0
SKIP_GENERATE=0
OUTPUT_DIR="${ROOT_DIR}/build/release"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Archives a Release build signed with Developer ID, exports ${APP_NAME}.app,
packages it into a DMG, notarizes and staples the DMG, and prints its SHA-256.

Options:
  -n, --dry-run         Print the commands without running them
      --skip-notarize   Build and sign the DMG, but do not notarize or staple
      --skip-generate   Do not run 'xcodegen generate' first
  -o, --output DIR      Output directory (default: build/release)
  -h, --help            Show this help

Required environment variables:
  DEVELOPER_ID_APPLICATION  Developer ID Application signing identity
  DEVELOPMENT_TEAM          Apple Developer Team ID
  NOTARY_PROFILE            notarytool keychain profile (not needed with --skip-notarize)

Example:
  export DEVELOPER_ID_APPLICATION="Developer ID Application: Example Inc (ABCDE12345)"
  export DEVELOPMENT_TEAM=ABCDE12345
  export NOTARY_PROFILE=ssfm-notary
  scripts/release.sh --dry-run
EOF
}

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Runs a command, or prints it in dry-run mode.
run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '  [dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n | --dry-run) DRY_RUN=1 ;;
            --skip-notarize) SKIP_NOTARIZE=1 ;;
            --skip-generate) SKIP_GENERATE=1 ;;
            -o | --output)
                [[ $# -ge 2 ]] || die "--output needs a directory"
                OUTPUT_DIR="$2"
                shift
                ;;
            -h | --help) usage; exit 0 ;;
            *) usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' not found. $2"
}

check_environment() {
    require_tool xcodebuild "Install Xcode and run xcode-select."
    require_tool hdiutil "hdiutil ships with macOS."
    require_tool shasum "shasum ships with macOS."
    [[ "${SKIP_GENERATE}" -eq 1 ]] || require_tool xcodegen "Run: brew install xcodegen"

    local missing=()
    [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]] || missing+=("DEVELOPER_ID_APPLICATION")
    [[ -n "${DEVELOPMENT_TEAM:-}" ]] || missing+=("DEVELOPMENT_TEAM")
    if [[ "${SKIP_NOTARIZE}" -eq 0 && -z "${NOTARY_PROFILE:-}" ]]; then
        missing+=("NOTARY_PROFILE")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            warn "missing environment variables (ignored in dry-run): ${missing[*]}"
            DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application: <name> (<team>)}"
            DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-<team>}"
            NOTARY_PROFILE="${NOTARY_PROFILE:-<profile>}"
        else
            die "missing environment variables: ${missing[*]} (see --help)"
        fi
    fi

    if [[ "${DRY_RUN}" -eq 0 ]] &&
        ! security find-identity -v -p codesigning | grep -Fq "${DEVELOPER_ID_APPLICATION}"; then
        die "signing identity not found in the keychain: ${DEVELOPER_ID_APPLICATION}"
    fi
}

read_version() {
    VERSION="$(sed -n 's/^[[:space:]]*CFBundleShortVersionString:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "${PROJECT_SPEC}" | head -n1)"
    BUILD="$(sed -n 's/^[[:space:]]*CFBundleVersion:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "${PROJECT_SPEC}" | head -n1)"
    [[ -n "${VERSION}" && -n "${BUILD}" ]] || die "could not read the version from project.yml"
}

write_export_options() {
    local plist="$1"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '  [dry-run] write %s\n' "${plist}"
        return
    fi
    cat >"${plist}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF
}

archive_and_export() {
    if [[ "${SKIP_GENERATE}" -eq 0 ]]; then
        log "Generating Xcode project"
        run xcodegen generate --spec "${PROJECT_SPEC}" --project "${ROOT_DIR}"
    fi

    log "Archiving ${APP_NAME} ${VERSION} (${BUILD})"
    run xcodebuild archive \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -archivePath "${ARCHIVE_PATH}" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION}" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
        ENABLE_HARDENED_RUNTIME=YES \
        OTHER_CODE_SIGN_FLAGS="--timestamp"

    log "Exporting app"
    write_export_options "${EXPORT_OPTIONS}"
    run xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportPath "${EXPORT_DIR}" \
        -exportOptionsPlist "${EXPORT_OPTIONS}"

    log "Verifying app signature"
    run codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
}

create_dmg() {
    log "Creating DMG"
    local staging="${OUTPUT_DIR}/dmg-staging"
    run rm -rf "${staging}" "${DMG_PATH}"
    run mkdir -p "${staging}"
    run cp -R "${APP_PATH}" "${staging}/"
    run ln -s /Applications "${staging}/Applications"
    run hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${staging}" \
        -fs HFS+ \
        -format UDZO \
        -ov \
        "${DMG_PATH}"
    run rm -rf "${staging}"

    log "Signing DMG"
    run codesign --sign "${DEVELOPER_ID_APPLICATION}" --timestamp "${DMG_PATH}"
}

notarize() {
    if [[ "${SKIP_NOTARIZE}" -eq 1 ]]; then
        warn "skipping notarization; this DMG will be blocked by Gatekeeper on other Macs"
        return
    fi
    log "Submitting to the notary service (this can take several minutes)"
    run xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

    log "Stapling ticket"
    run xcrun stapler staple "${DMG_PATH}"
    run xcrun stapler validate "${DMG_PATH}"
    run spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG_PATH}"
}

print_summary() {
    local sha="<sha256>"
    local size="<bytes>"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        sha="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
        size="$(stat -f%z "${DMG_PATH}")"
        printf '%s  %s\n' "${sha}" "$(basename "${DMG_PATH}")" >"${DMG_PATH}.sha256"
    fi

    cat <<EOF

Release artifact
  File:    ${DMG_PATH}
  Version: ${VERSION} (${BUILD})
  Size:    ${size} bytes
  SHA-256: ${sha}

Next steps
  1. Test the DMG on a clean Mac or a fresh user account (Gatekeeper, permissions, launch).
  2. Move the "Unreleased" entries in CHANGELOG.md under "## [${VERSION}]" and commit.
  3. Tag the release:   git tag -a v${VERSION} -m "v${VERSION}" && git push origin v${VERSION}
  4. Create a GitHub release for v${VERSION}, attach the DMG and its .sha256 file.
  5. Sparkle appcast: not integrated yet (TODO, see docs/RELEASING.md).
EOF
}

main() {
    parse_args "$@"
    cd "${ROOT_DIR}"
    check_environment
    read_version

    ARCHIVE_PATH="${OUTPUT_DIR}/${APP_NAME}.xcarchive"
    EXPORT_DIR="${OUTPUT_DIR}/export"
    EXPORT_OPTIONS="${OUTPUT_DIR}/ExportOptions.plist"
    APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
    DMG_PATH="${OUTPUT_DIR}/${APP_NAME}-${VERSION}.dmg"

    [[ "${DRY_RUN}" -eq 1 ]] && log "Dry run: nothing will be built, signed or uploaded"
    run mkdir -p "${OUTPUT_DIR}"

    archive_and_export
    create_dmg
    notarize
    print_summary
}

main "$@"
