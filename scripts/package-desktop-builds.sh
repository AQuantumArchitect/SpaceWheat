#!/bin/bash
# package-desktop-builds.sh - Package exported desktop builds for redistribution

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/log.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/release_paths.sh"

OUTPUT_ROOT="$(sw_desktop_export_root)"
PACKAGE_ROOT="$(sw_package_root)"

# Default version = application/config/version in project.godot (the same string
# the title screen shows), so archives and in-game stamp can't drift apart.
VERSION_TAG="${VERSION_TAG:-$(sw_project_version)}"

show_help() {
    cat << 'EOF'
Package local desktop exports into distributable archives.

Usage:
  ./scripts/package-desktop-builds.sh [OPTIONS]

Options:
  --output-root PATH       Export root to package (default: ./releases/local)
  --package-root PATH      Archive output root (default: ./releases/packages)
  --version TAG            Version label (default: config/version from project.godot, else dev)
  --help                   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --package-root)
            PACKAGE_ROOT="$2"
            shift 2
            ;;
        --version)
            VERSION_TAG="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

WINDOWS_DIR="$OUTPUT_ROOT/windows-native"
LINUX_DIR="$OUTPUT_ROOT/linux-native"

[ -d "$WINDOWS_DIR" ] || error "Missing Windows export folder: $WINDOWS_DIR"
[ -d "$LINUX_DIR" ] || error "Missing Linux export folder: $LINUX_DIR"
command -v tar >/dev/null 2>&1 || error "tar not found"
command -v python3 >/dev/null 2>&1 || error "python3 not found"

mkdir -p "$PACKAGE_ROOT"

# Twemoji is CC-BY 4.0 and attribution is its ONE condition. The rc3 archives
# carried binaries only (windows zip = 2 entries, linux tar = 3), so that
# condition was unmet in every artifact shipped so far. These two files are not
# paperwork — they are the licence terms travelling with the thing they cover.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for legal in LICENSE THIRD_PARTY_NOTICES.md; do
    [ -f "$REPO_ROOT/$legal" ] || error "Missing $legal — refusing to package an archive without its licence"
    cp "$REPO_ROOT/$legal" "$WINDOWS_DIR/$legal"
    cp "$REPO_ROOT/$legal" "$LINUX_DIR/$legal"
done

WINDOWS_ARCHIVE="$PACKAGE_ROOT/spacewheat-windows-${VERSION_TAG}.zip"
LINUX_ARCHIVE="$PACKAGE_ROOT/spacewheat-linux-${VERSION_TAG}.tar.gz"

log "Packaging Windows build"
rm -f "$WINDOWS_ARCHIVE"
if command -v zip >/dev/null 2>&1; then
    (
        cd "$WINDOWS_DIR"
        zip -q -r "$WINDOWS_ARCHIVE" .
    )
else
    python3 - "$WINDOWS_DIR" "$WINDOWS_ARCHIVE" <<'PY'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(source.rglob("*")):
        if path.is_file():
            zf.write(path, path.relative_to(source))
PY
fi
success "Windows archive: $WINDOWS_ARCHIVE"

log "Packaging Linux build"
rm -f "$LINUX_ARCHIVE"
(
    cd "$LINUX_DIR"
    tar -czf "$LINUX_ARCHIVE" .
)
success "Linux archive: $LINUX_ARCHIVE"
