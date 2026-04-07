#!/bin/bash
# install-godot-export-templates.sh - Install official Godot export templates
#
# Usage:
#   ./scripts/install-godot-export-templates.sh
#   ./scripts/install-godot-export-templates.sh --version 4.5.stable
#   ./scripts/install-godot-export-templates.sh --godot-bin godot

set -euo pipefail

GODOT_BIN="godot"
VERSION_OVERRIDE=""

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
Install official Godot export templates into the path expected by the editor.

Usage:
  ./scripts/install-godot-export-templates.sh [OPTIONS]

Options:
  --version VERSION       Override Godot template version (example: 4.5.stable)
  --godot-bin PATH        Godot executable to inspect (default: godot)
  --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION_OVERRIDE="${2:-}"
            shift 2
            ;;
        --godot-bin)
            GODOT_BIN="${2:-}"
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

command -v "$GODOT_BIN" >/dev/null 2>&1 || error "Godot binary not found: $GODOT_BIN"
command -v curl >/dev/null 2>&1 || error "curl not found. Install it first."
command -v unzip >/dev/null 2>&1 || error "unzip not found. Install it first."

GODOT_VERSION="$VERSION_OVERRIDE"
if [ -z "$GODOT_VERSION" ]; then
    GODOT_VERSION="$("$GODOT_BIN" --version | head -1)"
fi

GODOT_VERSION="${GODOT_VERSION%%.official*}"
RELEASE_TAG="${GODOT_VERSION/.stable/-stable}"
RELEASE_TAG="${RELEASE_TAG/.beta/-beta}"
RELEASE_TAG="${RELEASE_TAG/.rc/-rc}"

TEMPLATE_URL="https://github.com/godotengine/godot/releases/download/${RELEASE_TAG}/Godot_v${RELEASE_TAG}_export_templates.tpz"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}"
TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="$TMP_DIR/templates.tpz"
UNPACK_DIR="$TMP_DIR/unpacked"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log "Installing Godot export templates"
echo "  Version: $GODOT_VERSION"
echo "  Source:  $TEMPLATE_URL"
echo "  Target:  $INSTALL_DIR"

mkdir -p "$UNPACK_DIR"
curl -L "$TEMPLATE_URL" -o "$ARCHIVE_PATH"
unzip -q "$ARCHIVE_PATH" -d "$UNPACK_DIR"

SOURCE_DIR="$UNPACK_DIR"
if [ -d "$UNPACK_DIR/templates" ]; then
    SOURCE_DIR="$UNPACK_DIR/templates"
fi

mkdir -p "$INSTALL_DIR"
cp -R "$SOURCE_DIR"/. "$INSTALL_DIR"/

success "Installed export templates to $INSTALL_DIR"
