#!/bin/bash
# build-web-local.sh - Build local Web export with native WASM extension

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/releases/web-local}"
GODOT_TMP_ROOT="${GODOT_TMP_ROOT:-/tmp/spacewheat-godot-web-export}"
INSTALL_TEMPLATES=false
BUILD_NATIVE=true

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
Build the SpaceWheat Web export from the current checkout.

Usage:
  ./scripts/build-web-local.sh [OPTIONS]

Options:
  --output-root PATH       Export root (default: ./releases/web-local)
  --skip-native            Reuse existing web WASM extension
  --install-templates      Install Godot export templates if missing
  --godot-bin PATH         Godot executable (default: godot)
  --help                   Show this help

Outputs:
  <output-root>/index.html
  <output-root>/libquantummatrix.wasm   (inside export payload if included by Godot)
EOF
}

run_godot_export() {
    mkdir -p \
        "$GODOT_TMP_ROOT/runtime" \
        "$GODOT_TMP_ROOT/config" \
        "$GODOT_TMP_ROOT/cache"
    env \
        XDG_RUNTIME_DIR="$GODOT_TMP_ROOT/runtime" \
        XDG_CONFIG_HOME="$GODOT_TMP_ROOT/config" \
        XDG_CACHE_HOME="$GODOT_TMP_ROOT/cache" \
        "$GODOT_BIN" --headless "$@"
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
        --install-templates)
            INSTALL_TEMPLATES=true
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
    log "Building Web native extension"
    "$PROJECT_DIR/scripts/build-all-platforms.sh" --web-only
else
    warn "Skipping web native build"
fi

log "Exporting Web build"
rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT"

cd "$PROJECT_DIR"
run_godot_export --export-release "Web" "$OUTPUT_ROOT/index.html"

success "Web export ready: $OUTPUT_ROOT/index.html"
echo ""
echo "Built folder:"
echo "  Web: $OUTPUT_ROOT"
echo ""
echo "Next:"
echo "  python3 \"$PROJECT_DIR/scripts/serve-web-local.py\" \"$OUTPUT_ROOT\" --port 8000"
