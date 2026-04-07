#!/bin/bash
# package-desktop-builds.sh - Package exported desktop builds for redistribution

set -euo pipefail

OUTPUT_ROOT="${OUTPUT_ROOT:-$(pwd)/releases/local}"
PACKAGE_ROOT="${PACKAGE_ROOT:-$(pwd)/releases/packages}"
VERSION_TAG="${VERSION_TAG:-dev}"

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
Package local desktop exports into distributable archives.

Usage:
  ./scripts/package-desktop-builds.sh [OPTIONS]

Options:
  --output-root PATH       Export root to package (default: ./releases/local)
  --package-root PATH      Archive output root (default: ./releases/packages)
  --version TAG            Version label (default: dev)
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
command -v zip >/dev/null 2>&1 || error "zip not found"
command -v tar >/dev/null 2>&1 || error "tar not found"

mkdir -p "$PACKAGE_ROOT"

WINDOWS_ARCHIVE="$PACKAGE_ROOT/spacewheat-windows-${VERSION_TAG}.zip"
LINUX_ARCHIVE="$PACKAGE_ROOT/spacewheat-linux-${VERSION_TAG}.tar.gz"

log "Packaging Windows build"
rm -f "$WINDOWS_ARCHIVE"
(
    cd "$WINDOWS_DIR"
    zip -q -r "$WINDOWS_ARCHIVE" .
)
success "Windows archive: $WINDOWS_ARCHIVE"

log "Packaging Linux build"
rm -f "$LINUX_ARCHIVE"
(
    cd "$LINUX_DIR"
    tar -czf "$LINUX_ARCHIVE" .
)
success "Linux archive: $LINUX_ARCHIVE"
