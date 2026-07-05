#!/bin/bash
# build-linux-release.sh - Build and package SpaceWheat Linux release
#
# Usage:
#   ./scripts/build-linux-release.sh                    # Build the default version
#   ./scripts/build-linux-release.sh --version v0.3.0   # Build a specific version
#   ./scripts/build-linux-release.sh --install          # Build + install to games folder
#   ./scripts/build-linux-release.sh --clean            # Force rebuild godot-cpp
#
# This script (Linux only):
#   1. Clones a fresh repo to the build directory
#   2. Builds godot-cpp (cached unless --clean)
#   3. Builds the C++ extension
#   4. Warms Godot's import + class cache (double import; a cold clone can't compile)
#   5. Exports the game via Godot headless
#   6. Smoke-tests the exported binary and REFUSES to ship if it boots with errors
#   7. Creates the tarball in releases/linux/
#   8. Optionally installs to ~/games/SpaceWheat/

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/godot_runtime_env.sh"   # sw_write_linux_launcher, sw_godot_bin

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
REPO_URL="git@github.com:AQuantumArchitect/SpaceWheat.git"
BUILD_DIR="$HOME/ws/tmp/SpaceWheat-build"
GODOT_CPP_CACHE="$HOME/ws/tmp/godot-cpp-cache"
RELEASE_DIR="$(dirname "$SCRIPT_DIR")/releases/linux"
INSTALL_DIR="$HOME/games/SpaceWheat"
GODOT_BIN="$(sw_godot_bin)"

# Defaults
VERSION="v0.2.0"
DO_INSTALL=false
DO_CLEAN=false
SKIP_CPP=false
SKIP_EXPORT=false
VERBOSE=false

# ─────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────
log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }
debug() { [ "$VERBOSE" = true ] && echo -e "\033[0;90m  $1\033[0m"; }

show_help() {
    cat << 'EOF'
SpaceWheat Linux Release Builder

USAGE:
    build-linux-release.sh [OPTIONS]

OPTIONS:
    --version, -v VERSION   Set release version (default: v0.2.0)
    --install, -i           Install to ~/games/SpaceWheat after build
    --clean, -c             Force rebuild of godot-cpp (normally cached)
    --skip-cpp              Skip C++ build (use existing binaries)
    --skip-export           Skip Godot export (use existing export)
    --verbose               Show detailed output
    --help, -h              Show this help message

NOTE: produces a LINUX release only. For Windows/cross-platform builds use
      build-desktop-local.sh + package-desktop-builds.sh.

EXAMPLES:
    # Basic build
    ./scripts/build-linux-release.sh

    # Build v0.2.0 and install
    ./scripts/build-linux-release.sh --version v0.2.0 --install

    # Quick rebuild (skip C++ if unchanged)
    ./scripts/build-linux-release.sh --skip-cpp --install

    # Full clean rebuild
    ./scripts/build-linux-release.sh --clean --install

ENVIRONMENT:
    GODOT_BIN       Path to Godot binary (default: godot)

OUTPUT:
    Tarball: ~/ws/SpaceWheat/releases/linux/spacewheat-linux-VERSION.tar.gz
    Install: ~/games/SpaceWheat/ (with --install)

EOF
    exit 0
}

# ─────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --install|-i)
            DO_INSTALL=true
            shift
            ;;
        --clean|-c)
            DO_CLEAN=true
            shift
            ;;
        --skip-cpp)
            SKIP_CPP=true
            shift
            ;;
        --skip-export)
            SKIP_EXPORT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            error "Unknown option: $1 (use --help for usage)"
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# Validate environment
# ─────────────────────────────────────────────────────────────
log "Validating environment..."

if ! command -v $GODOT_BIN &> /dev/null; then
    error "Godot not found. Set GODOT_BIN or ensure 'godot' is in PATH."
fi

if ! command -v scons &> /dev/null; then
    error "scons not found. Install with: pip install scons"
fi

if ! command -v g++ &> /dev/null; then
    error "g++ not found. Install build-essential."
fi

GODOT_VERSION=$($GODOT_BIN --version 2>/dev/null | head -1)
success "Environment OK (Godot: $GODOT_VERSION)"

echo ""
echo "  Version:     $VERSION"
echo "  Install:     $DO_INSTALL"
echo "  Clean:       $DO_CLEAN"
echo "  Skip C++:    $SKIP_CPP"
echo "  Skip Export: $SKIP_EXPORT"

# ─────────────────────────────────────────────────────────────
# Step 1: Clone fresh repo
# ─────────────────────────────────────────────────────────────
log "Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

git clone --recurse-submodules "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"

COMMIT_HASH=$(git rev-parse --short HEAD)
success "Cloned repo to $BUILD_DIR (commit: $COMMIT_HASH)"

# ─────────────────────────────────────────────────────────────
# Step 2: Build godot-cpp (with caching)
# ─────────────────────────────────────────────────────────────
GODOT_CPP_LIB="libgodot-cpp.linux.template_release.x86_64.a"

if [ "$DO_CLEAN" = true ]; then
    log "Cleaning godot-cpp cache (--clean)..."
    rm -rf "$GODOT_CPP_CACHE"
fi

mkdir -p "$GODOT_CPP_CACHE"

if [ -f "$GODOT_CPP_CACHE/$GODOT_CPP_LIB" ]; then
    log "Using cached godot-cpp..."
    mkdir -p "$BUILD_DIR/native/lib"
    cp "$GODOT_CPP_CACHE/$GODOT_CPP_LIB" "$BUILD_DIR/native/lib/"
    success "Copied cached godot-cpp library"
else
    log "Building godot-cpp (this takes ~5 minutes)..."
    cd "$BUILD_DIR/godot-cpp"
    scons platform=linux target=template_release -j$(nproc)

    # Cache it for next time
    cp "bin/$GODOT_CPP_LIB" "$GODOT_CPP_CACHE/"
    mkdir -p "$BUILD_DIR/native/lib"
    cp "bin/$GODOT_CPP_LIB" "$BUILD_DIR/native/lib/"
    success "godot-cpp built and cached"
fi

# ─────────────────────────────────────────────────────────────
# Step 3: Build C++ extension
# ─────────────────────────────────────────────────────────────
if [ "$SKIP_CPP" = true ]; then
    warn "Skipping C++ build (--skip-cpp)"
else
    log "Building C++ extension..."
    cd "$BUILD_DIR/native"
    make clean 2>/dev/null || true
    make -j$(nproc)

    SO_FILE=$(ls -1 bin/linux/*.so 2>/dev/null | grep -v debug | head -1 || true)
    { [ -n "$SO_FILE" ] && [ -f "$SO_FILE" ]; } || error "C++ build produced no .so in native/bin/linux/"
    success "C++ extension built: $(du -h "$SO_FILE" | cut -f1)"
fi

EXPORT_DIR="$BUILD_DIR/export/SpaceWheat"

# ─────────────────────────────────────────────────────────────
# Step 4: Warm Godot's import + global class cache
# ─────────────────────────────────────────────────────────────
# A fresh clone has no .godot, so the first compile pass can't resolve class_name /
# autoload symbols ("Could not find type X"). Import TWICE: pass 1 registers class_names
# into global_script_class_cache.cfg, pass 2 compiles cleanly against it. Isolate Godot's
# config/data under the build dir (no global ~/.config pollution); drop the stale
# extension list so the export resolves the freshly-built .so.
if [ "$SKIP_EXPORT" != true ]; then
    log "Warming Godot import + class cache..."
    cd "$BUILD_DIR"
    [ -f "$BUILD_DIR/export_presets.cfg" ] || error "export_presets.cfg not found in the cloned repo"
    # Isolate only CONFIG (editor settings) under the build dir. DATA_HOME must stay at the
    # real data home — that's where the export TEMPLATES live (godot/export_templates/...);
    # isolating it would make the export fail with "No export template found".
    export XDG_CONFIG_HOME="$BUILD_DIR/.build/xdg-config"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
    rm -f "$BUILD_DIR/.godot/extension_list.cfg"
    timeout 180 "$GODOT_BIN" --headless --import . >/dev/null 2>&1 || true
    timeout 180 "$GODOT_BIN" --headless --import . >/dev/null 2>&1 || true
    [ -f "$BUILD_DIR/.godot/global_script_class_cache.cfg" ] \
        || error "Class cache not generated after import — the clone can't compile its scripts. Aborting."
    success "Class cache warm"
fi

# ─────────────────────────────────────────────────────────────
# Step 5: Export game with Godot (cache warmed above)
# ─────────────────────────────────────────────────────────────
# (No operator-cache step: operators are built on demand from icons.json/biomes.json
# at biome realization — ~0.7 ms/biome — so there is no bundled cache to refresh. The
# builders are the single authority for derived physics.)
if [ "$SKIP_EXPORT" = true ]; then
    warn "Skipping Godot export (--skip-export)"
    [ -d "$EXPORT_DIR" ] || error "No existing export found. Remove --skip-export."
else
    log "Exporting game with Godot..."
    cd "$BUILD_DIR"
    mkdir -p "$EXPORT_DIR"
    "$GODOT_BIN" --headless --export-release "Linux Desktop" "$EXPORT_DIR/SpaceWheat.x86_64" 2>&1 | grep -v "^$" || true
    [ -f "$EXPORT_DIR/SpaceWheat.x86_64" ] || error "Export failed — SpaceWheat.x86_64 not created. Check export preset."
    success "Game exported"
fi

# Copy C++ extension to export
log "Packaging C++ extension with export..."
cp "$BUILD_DIR/native/bin/linux/"*.so "$EXPORT_DIR/" 2>/dev/null || warn "No .so files to copy"

# WSL-aware launcher (shared helper in godot_runtime_env.sh; was a brittle one-liner).
if [ ! -f "$EXPORT_DIR/launch.sh" ]; then
    sw_write_linux_launcher "$EXPORT_DIR"
fi

# ─────────────────────────────────────────────────────────────
# Step 6: Smoke-test the exported build — never ship a broken release
# ─────────────────────────────────────────────────────────────
# Boot the actual exported binary (with its bundled .so) headless and refuse to package
# if it logs any SCRIPT ERROR / ERROR: — this catches a cold/broken export, a missing
# extension, or an incomplete economy config (which hard-fails at boot by design).
if [ "$SKIP_EXPORT" != true ]; then
    log "Smoke-testing the exported build..."
    smoke_log=$(timeout 60 "$EXPORT_DIR/SpaceWheat.x86_64" --headless --audio-driver Dummy --quit 2>&1 || true)
    smoke_errors=$(printf '%s\n' "$smoke_log" | grep -cE "SCRIPT ERROR|ERROR:" || true)
    if [ "${smoke_errors:-0}" -ne 0 ]; then
        printf '%s\n' "$smoke_log" | grep -E "SCRIPT ERROR|ERROR:" | head -10
        error "Exported build boots with ${smoke_errors} error(s) — refusing to ship a broken release."
    fi
    success "Exported build boots clean (0 errors)"
fi

# ─────────────────────────────────────────────────────────────
# Step 7: Create tarball
# ─────────────────────────────────────────────────────────────
log "Creating release tarball..."
mkdir -p "$RELEASE_DIR"
TARBALL="$RELEASE_DIR/spacewheat-linux-${VERSION}.tar.gz"

cd "$BUILD_DIR/export"
tar czf "$TARBALL" SpaceWheat/

TARBALL_SIZE=$(du -h "$TARBALL" | cut -f1)
success "Release created: $TARBALL ($TARBALL_SIZE)"

# ─────────────────────────────────────────────────────────────
# Step 8: Install (optional)
# ─────────────────────────────────────────────────────────────
if [ "$DO_INSTALL" = true ]; then
    log "Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    tar xzf "$TARBALL" -C "$(dirname "$INSTALL_DIR")"

    # Verify
    if [ -f "$INSTALL_DIR/SpaceWheat.x86_64" ]; then
        success "Installed to $INSTALL_DIR"
    else
        error "Installation verification failed"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────
log "Cleaning up build directory..."
rm -rf "$BUILD_DIR"
success "Build directory cleaned"

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "\033[1;32m✓ SpaceWheat Linux $VERSION build complete!\033[0m"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Tarball:  $TARBALL"
echo "  Size:     $TARBALL_SIZE"
echo "  Commit:   $COMMIT_HASH"
echo ""

if [ "$DO_INSTALL" = true ]; then
    echo "  Installed: $INSTALL_DIR"
    echo ""
    echo "  Run with:"
    echo "    $INSTALL_DIR/SpaceWheat.x86_64"
    echo ""
fi

echo "  Upload to GitHub Releases:"
echo "    gh release create $VERSION $TARBALL --title \"SpaceWheat $VERSION\""
echo ""
echo "  Upload to itch.io (with butler):"
echo "    butler push $TARBALL yourname/spacewheat:linux"
echo ""
echo "════════════════════════════════════════════════════════════"
