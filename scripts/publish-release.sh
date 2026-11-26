#!/usr/bin/env bash
# Publishes a notarized DMG (produced by scripts/release.sh) as a GitHub Release,
# together with a Sparkle appcast signed with the EdDSA key stored in the Keychain.
#
# The app's SUFeedURL points at .../releases/latest/download/appcast.xml, so every
# release must carry an appcast.xml asset.
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_NAME="ScreenShotForMac"
readonly REPO="${GITHUB_REPO:-atak946/ScreenShotForMac}"
readonly KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-ScreenShotForMac}"
readonly SPARKLE_BIN="${SPARKLE_BIN:-${ROOT_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin}"
readonly RELEASE_DIR="${ROOT_DIR}/build/release"
readonly APPCAST_DIR="${ROOT_DIR}/build/appcast"

DRY_RUN=0
DRAFT=0
NOTES_FILE=""

usage() {
    cat <<USAGE
Usage: scripts/publish-release.sh [--notes FILE] [--draft] [--dry-run]

Requires: build/release/${APP_NAME}-<version>.dmg (run scripts/release.sh first),
Sparkle tools (resolved by an Xcode build, or set SPARKLE_BIN), and an authenticated gh CLI.

  --notes FILE  Release notes (Markdown). Defaults to the CHANGELOG "Unreleased" section.
  --draft       Create the GitHub Release as a draft.
  --dry-run     Print the commands without running them.
USAGE
}

run() {
    echo "+ $*"
    if [[ "${DRY_RUN}" -eq 0 ]]; then "$@"; fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes) NOTES_FILE="$2"; shift 2 ;;
        --draft) DRAFT=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 64 ;;
    esac
done

VERSION="$(sed -n 's/^[[:space:]]*CFBundleShortVersionString:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "${ROOT_DIR}/project.yml" | head -n1)"
readonly VERSION
readonly TAG="v${VERSION}"
readonly DMG="${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg"

[[ -f "${DMG}" ]] || { echo "Missing ${DMG}. Run scripts/release.sh first." >&2; exit 66; }
[[ -x "${SPARKLE_BIN}/generate_appcast" ]] || { echo "Sparkle tools not found in ${SPARKLE_BIN}." >&2; exit 69; }
command -v gh >/dev/null || { echo "gh CLI is required." >&2; exit 69; }

if [[ -z "${NOTES_FILE}" ]]; then
    NOTES_FILE="$(mktemp)"
    awk '/^## \[Unreleased\]/{flag=1; next} /^## \[/{flag=0} flag' "${ROOT_DIR}/CHANGELOG.md" > "${NOTES_FILE}"
fi

# 1. Appcast: generate_appcast signs the DMG with the Keychain EdDSA key and writes appcast.xml.
#    Older DMGs stay in build/appcast so the feed keeps the full history.
run mkdir -p "${APPCAST_DIR}"
run cp "${DMG}" "${APPCAST_DIR}/"
run "${SPARKLE_BIN}/generate_appcast" \
    --account "${KEY_ACCOUNT}" \
    --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" \
    --link "https://github.com/${REPO}" \
    "${APPCAST_DIR}"

# 2. GitHub Release with the DMG and the appcast.
release_args=(release create "${TAG}" "${DMG}" "${APPCAST_DIR}/appcast.xml"
    --repo "${REPO}" --title "${APP_NAME} ${VERSION}" --notes-file "${NOTES_FILE}" --verify-tag)
if [[ "${DRAFT}" -eq 1 ]]; then release_args+=(--draft); fi
run git -C "${ROOT_DIR}" tag -a "${TAG}" -m "${APP_NAME} ${VERSION}"
run git -C "${ROOT_DIR}" push origin "${TAG}"
run gh "${release_args[@]}"

echo "Published ${TAG}: https://github.com/${REPO}/releases/tag/${TAG}"
