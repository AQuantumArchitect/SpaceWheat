#!/bin/bash
# build-desktop-local.sh - Build local Linux and Windows desktop exports
#
# Uses the current checkout, current export presets, and the native build path
# proven in this workspace. Intended for repeatable local release prep.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/windows_desktop_deploy.sh"
source "$SCRIPT_DIR/lib/godot_runtime_env.sh"
GODOT_BIN="$(sw_godot_bin)"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/releases/local}"
GODOT_EXPORT_CONFIG_HOME="${GODOT_EXPORT_CONFIG_HOME:-$PROJECT_DIR/.build/xdg-config}"
GODOT_EXPORT_DATA_HOME="${GODOT_EXPORT_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"
BUILD_NATIVE=true
INSTALL_TEMPLATES=false
CLEAN_NATIVE=false
SKIP_EXPORT=false
COPY_TO_WINDOWS=false
WINDOWS_STAGE_OUT="${WINDOWS_STAGE_OUT:-${WINDOWS_STAGE_ROOT:-$(sw_windows_stage_root)}/windows-native}"

source "$SCRIPT_DIR/lib/log.sh"

sanitize_godot_export_state() {
    local extension_cache="$PROJECT_DIR/.godot/extension_list.cfg"
    if [ -f "$extension_cache" ]; then
        rm -f "$extension_cache"
    fi
}

run_godot_export() {
    mkdir -p "$GODOT_EXPORT_CONFIG_HOME"
    XDG_CONFIG_HOME="$GODOT_EXPORT_CONFIG_HOME" \
    XDG_DATA_HOME="$GODOT_EXPORT_DATA_HOME" \
        "$GODOT_BIN" --headless "$@"
}

# Which commit this pack was cut from. Core/Config/BuildInfo.gd reads it and the
# title screen + bug-report clipboard show it. Written here rather than typed by
# hand because the hand-typed half (config/version) sat 66 commits stale once
# already; a stamp nobody types cannot go stale. Removed again after the export
# so a source run honestly reports "source" instead of the last build's commit.
BUILD_STAMP_FILE="$PROJECT_DIR/Core/Config/build_stamp.json"

write_build_stamp() {
    local sha branch built
    sha="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    built="$(date -u +%Y-%m-%d)"
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
        sha="${sha}-dirty"   # a pack built off uncommitted edits must say so
    fi
    printf '{"commit": "%s", "branch": "%s", "built": "%s"}\n' \
        "$sha" "$branch" "$built" > "$BUILD_STAMP_FILE"
    log "Build stamp: $sha ($branch, $built)"
}

remove_build_stamp() {
    rm -f "$BUILD_STAMP_FILE" "$BUILD_STAMP_FILE.import" "$BUILD_STAMP_FILE.uid"
}
trap remove_build_stamp EXIT

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
  --copy-to-windows        Copy the Windows export into the Windows staging folder
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

log "Sanitizing Godot export state"
sanitize_godot_export_state

write_build_stamp
# The stamp is a brand-new file; import it so the exporter packs it rather than
# silently shipping a build that reports "source".
run_godot_export --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

log "Exporting desktop builds"
rm -rf "$WINDOWS_OUT" "$LINUX_OUT"
mkdir -p "$WINDOWS_OUT" "$LINUX_OUT"

cd "$PROJECT_DIR"
run_godot_export --export-release "Windows Desktop" "$WINDOWS_OUT/SpaceWheat.exe"
run_godot_export --export-release "Linux Desktop" "$LINUX_OUT/SpaceWheat.x86_64"

success "Windows export ready: $WINDOWS_OUT/SpaceWheat.exe"
success "Linux export ready: $LINUX_OUT/SpaceWheat.x86_64"

if [ ! -f "$LINUX_OUT/launch.sh" ]; then
    sw_write_linux_launcher "$LINUX_OUT"   # shared helper in godot_runtime_env.sh
fi

if [ "$COPY_TO_WINDOWS" = true ]; then
    log "Refreshing Windows staging folder"
    if sw_windows_deploy_tree "$WINDOWS_OUT" "$WINDOWS_STAGE_OUT" 0; then
        success "Windows staging folder refreshed: $WINDOWS_STAGE_OUT"
    else
        warn "Windows staging folder refresh failed"
    fi
fi

echo ""
echo "Built folders:"
echo "  Windows: $WINDOWS_OUT"
echo "  Linux:   $LINUX_OUT"
