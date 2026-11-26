#!/usr/bin/env bash
#
# Builds the `ssfm` command-line tool (release) and installs it into a bin directory.
#
#   scripts/install-cli.sh                 # installs to /usr/local/bin (may ask for sudo)
#   scripts/install-cli.sh --prefix ~/bin  # installs to a user-writable directory
#   scripts/install-cli.sh --link          # symlinks instead of copying (keeps tracking .build)
#
# Only local files are touched; nothing is downloaded beyond Swift package dependencies.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PRODUCT="ssfm"

PREFIX="/usr/local/bin"
MODE="copy"

usage() {
    sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            [[ $# -ge 2 ]] || { echo "error: --prefix needs a directory" >&2; exit 64; }
            PREFIX="$2"
            shift 2
            ;;
        --link) MODE="link"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage >&2; exit 64 ;;
    esac
done

echo "==> Building ${PRODUCT} (release)"
swift build --package-path "${ROOT_DIR}" -c release --product "${PRODUCT}"
BIN_DIR="$(swift build --package-path "${ROOT_DIR}" -c release --show-bin-path)"
readonly SOURCE="${BIN_DIR}/${PRODUCT}"
[[ -x "${SOURCE}" ]] || { echo "error: ${SOURCE} was not built" >&2; exit 1; }

SUDO=""
if [[ ! -d "${PREFIX}" ]]; then
    mkdir -p "${PREFIX}" 2>/dev/null || SUDO="sudo"
    ${SUDO} mkdir -p "${PREFIX}"
fi
if [[ ! -w "${PREFIX}" ]]; then
    echo "==> ${PREFIX} is not writable; using sudo (you may be asked for your password)"
    SUDO="sudo"
fi

readonly TARGET="${PREFIX}/${PRODUCT}"
if [[ "${MODE}" == "link" ]]; then
    ${SUDO} ln -sf "${SOURCE}" "${TARGET}"
else
    ${SUDO} install -m 0755 "${SOURCE}" "${TARGET}"
fi

echo "==> Installed ${TARGET}"
"${TARGET}" --version || true
