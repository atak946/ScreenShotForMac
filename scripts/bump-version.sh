#!/usr/bin/env bash
#
# Update CFBundleShortVersionString and CFBundleVersion in project.yml.
# Run `scripts/bump-version.sh --help` for options.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="${SPEC:-${SCRIPT_DIR}/../project.yml}"
DRY_RUN=0
NEW_VERSION=""
NEW_BUILD=""
BUMP=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [<version>] [<build>]

Sets the marketing version (CFBundleShortVersionString) and build number
(CFBundleVersion) in project.yml. The build number is incremented by one
unless you pass it explicitly.

Arguments:
  <version>       New marketing version, e.g. 1.2.0
  <build>         New build number (integer). Default: current build + 1

Options:
      --major     Bump the major version (1.2.3 -> 2.0.0)
      --minor     Bump the minor version (1.2.3 -> 1.3.0)
      --patch     Bump the patch version (1.2.3 -> 1.2.4)
      --build     Only increment the build number
  -n, --dry-run   Show the change without writing it
  -h, --help      Show this help

Examples:
  $(basename "$0") --patch
  $(basename "$0") 1.0.0
  $(basename "$0") 1.0.0 42
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

read_field() {
    sed -n "s/^[[:space:]]*$1:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*\$/\1/p" "${SPEC}" | head -n1
}

parse_args() {
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --major | --minor | --patch | --build)
                [[ -z "${BUMP}" ]] || die "use only one of --major, --minor, --patch, --build"
                BUMP="${1#--}"
                ;;
            -n | --dry-run) DRY_RUN=1 ;;
            -h | --help) usage; exit 0 ;;
            -*) usage >&2; die "unknown option: $1" ;;
            *) positional+=("$1") ;;
        esac
        shift
    done

    [[ ${#positional[@]} -le 2 ]] || die "too many arguments"
    NEW_VERSION="${positional[0]:-}"
    NEW_BUILD="${positional[1]:-}"
    if [[ -z "${BUMP}" && -z "${NEW_VERSION}" ]]; then
        usage >&2
        die "pass a version or one of --major, --minor, --patch, --build"
    fi
    [[ -z "${BUMP}" || -z "${NEW_VERSION}" ]] || die "pass either a version or a bump option, not both"
}

compute_version() {
    local current="$1"
    [[ "${current}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "current version '${current}' is not MAJOR.MINOR.PATCH"
    local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"
    case "${BUMP}" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
        *) echo "${current}" ;;
    esac
}

main() {
    parse_args "$@"
    [[ -f "${SPEC}" ]] || die "project spec not found: ${SPEC}"

    local current_version current_build
    current_version="$(read_field CFBundleShortVersionString)"
    current_build="$(read_field CFBundleVersion)"
    [[ -n "${current_version}" && -n "${current_build}" ]] || die "version fields not found in ${SPEC}"
    [[ "${current_build}" =~ ^[0-9]+$ ]] || die "current build '${current_build}' is not an integer"

    local version="${NEW_VERSION}"
    [[ -n "${version}" ]] || version="$(compute_version "${current_version}")"
    [[ "${version}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "invalid version: ${version}"

    local build="${NEW_BUILD:-$((current_build + 1))}"
    [[ "${build}" =~ ^[0-9]+$ ]] || die "build number must be an integer: ${build}"
    [[ "${build}" -gt "${current_build}" ]] || die "build number must increase (current: ${current_build})"

    printf 'Version: %s (%s) -> %s (%s)\n' "${current_version}" "${current_build}" "${version}" "${build}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "Dry run: project.yml not changed."
        return
    fi

    local tmp
    tmp="$(mktemp "${SPEC}.XXXXXX")"
    trap 'rm -f "${tmp}"' EXIT
    sed -E \
        -e "s/^([[:space:]]*CFBundleShortVersionString:[[:space:]]*).*/\1\"${version}\"/" \
        -e "s/^([[:space:]]*CFBundleVersion:[[:space:]]*).*/\1\"${build}\"/" \
        "${SPEC}" >"${tmp}"
    mv "${tmp}" "${SPEC}"
    trap - EXIT

    echo "Updated ${SPEC}. Run 'xcodegen generate' to apply it to the Xcode project."
}

main "$@"
