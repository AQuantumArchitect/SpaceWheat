#!/bin/bash
# build-desktop-local.sh - Build local Linux and Windows desktop exports
#
# Uses the current checkout, current export presets, and the native build path
# proven in this workspace. Intended for repeatable local release prep.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/releases/local}"
BUILD_NATIVE=true
INSTALL_TEMPLATES=false
CLEAN_NATIVE=false
SKIP_EXPORT=false
COPY_TO_WINDOWS=false
WINDOWS_STAGE_ROOT="${WINDOWS_STAGE_ROOT:-/mnt/c/Games/SpaceWheat Builds}"

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
Build SpaceWheat desktop exports from the current checkout.

Usage:
  ./scripts/build-desktop-local.sh [OPTIONS]

Options:
  --output-root PATH       Export root (default: ./releases/local)
  --skip-native            Reuse existing native binaries
  --clean-native           Rebuild godot-cpp/native artifacts
  --skip-export            Stop after native build
  --install-templates      Install Godot export templates if missing
  --copy-to-windows        Copy exported folders to /mnt/c/Games/SpaceWheat Builds
  --godot-bin PATH         Godot executable (default: godot)
  --help                   Show this help

Outputs:
  <output-root>/windows-native/SpaceWheat.exe
  <output-root>/linux-native/SpaceWheat.x86_64
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-root)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --skip-native)
            BUILD_NATIVE=false
            shift
            ;;
        --clean-native)
            CLEAN_NATIVE=true
            shift
            ;;
        --skip-export)
            SKIP_EXPORT=true
            shift
            ;;
        --install-templates)
            INSTALL_TEMPLATES=true
            shift
            ;;
        --copy-to-windows)
            COPY_TO_WINDOWS=true
            shift
            ;;
        --godot-bin)
            GODOT_BIN="$2"
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

command -v "$GODOT_BIN" >/dev/null 2>&1 || error "Godot not found: $GODOT_BIN"

if [ "$INSTALL_TEMPLATES" = true ]; then
    log "Installing export templates"
    "$PROJECT_DIR/scripts/install-godot-export-templates.sh" --godot-bin "$GODOT_BIN"
fi

if [ "$BUILD_NATIVE" = true ]; then
    log "Building native desktop binaries"
    NATIVE_ARGS=(--linux-only --windows-only)
    if [ "$CLEAN_NATIVE" = true ]; then
        NATIVE_ARGS+=(--clean)
    fi
    "$PROJECT_DIR/scripts/build-all-platforms.sh" "${NATIVE_ARGS[@]}"
else
    warn "Skipping native build"
fi

if [ "$SKIP_EXPORT" = true ]; then
    warn "Skipping export"
    exit 0
fi

WINDOWS_OUT="$OUTPUT_ROOT/windows-native"
LINUX_OUT="$OUTPUT_ROOT/linux-native"

log "Exporting desktop builds"
rm -rf "$WINDOWS_OUT" "$LINUX_OUT"
mkdir -p "$WINDOWS_OUT" "$LINUX_OUT"

cd "$PROJECT_DIR"
"$GODOT_BIN" --headless --export-release "Windows Desktop" "$WINDOWS_OUT/SpaceWheat.exe"
"$GODOT_BIN" --headless --export-release "Linux Desktop" "$LINUX_OUT/SpaceWheat.x86_64"

success "Windows export ready: $WINDOWS_OUT/SpaceWheat.exe"
success "Linux export ready: $LINUX_OUT/SpaceWheat.x86_64"

if [ "$COPY_TO_WINDOWS" = true ]; then
    if [ ! -d /mnt/c ]; then
        error "/mnt/c is not available; cannot copy to Windows filesystem."
    fi
    log "Copying builds to Windows filesystem"
    mkdir -p "$WINDOWS_STAGE_ROOT/windows-native" "$WINDOWS_STAGE_ROOT/linux-native"
    cp -f "$WINDOWS_OUT"/* "$WINDOWS_STAGE_ROOT/windows-native/"
    cp -f "$LINUX_OUT"/* "$WINDOWS_STAGE_ROOT/linux-native/"
    success "Copied builds to $WINDOWS_STAGE_ROOT"
fi

echo ""
echo "Built folders:"
echo "  Windows: $WINDOWS_OUT"
echo "  Linux:   $LINUX_OUT"
