#!/bin/bash
# build-all-platforms.sh - Build SpaceWheat native extensions for Linux, Windows, and Web
#
# Usage:
#   ./scripts/build-all-platforms.sh                # Build all platforms
#   ./scripts/build-all-platforms.sh --clean        # Rebuild godot-cpp
#   ./scripts/build-all-platforms.sh --linux-only   # Build Linux only
#   ./scripts/build-all-platforms.sh --help         # Show help

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NATIVE_DIR="$PROJECT_DIR/native"
GODOT_CPP_DIR="$PROJECT_DIR/godot-cpp"
source "$SCRIPT_DIR/lib/native_build_state.sh"

# The Emscripten the Godot web export template was built with. This is a HARD
# pin, not a preference.
#
# A side module compiled by a different emsdk links against a different libc++,
# whose mangled symbol names do not match what the engine's main module exports.
# The extension still loads — dlopen succeeds and the Eigen banner prints — and
# then aborts at the first call into an unresolved stub. 0.1.0-alpha shipped
# exactly that: built with emsdk 5.0.6 against a 4.0.10 template, 29 unresolved
# libc++ imports, and the browser build died on
# `undefined symbol '_ZNSt3__213__hash_memoryEPKvm'` the instant a farm booted.
# The title card looked fine, so nothing caught it.
#
# Read the truth out of a running export: the engine prints
# "Build configuration: Emscripten <version>, multi-threaded, GDExtension support."
# in the browser console at boot. Match this to that.
SW_EMSDK_VERSION="4.0.10"

# Options
DO_CLEAN=false
LINUX_ONLY=false
WINDOWS_ONLY=false
WEB_ONLY=false

source "$SCRIPT_DIR/lib/log.sh"

show_help() {
    cat << 'EOF'
SpaceWheat Multi-Platform Native Builder

Builds C++ extensions for Linux, Windows (MinGW cross-compile), and Web (Emscripten).

Important:
  - Linux and Windows outputs are part of the current desktop shipping path.
  - The current Web export preset has extensions support enabled, but the
    browser/runtime lane is still experimental until there is a real smoke
    and performance validation path.

Usage:
  ./scripts/build-all-platforms.sh [OPTIONS]

Options:
  --clean         Rebuild godot-cpp for all platforms
  --linux-only    Build Linux extension only
  --windows-only  Build Windows extension only
  --web-only      Build Web (WASM) extension only
  --help          Show this help

Prerequisites:
  - MinGW:      sudo apt-get install mingw-w64
  - Emscripten: source ~/emsdk/emsdk_env.sh
  - SCons:      pip3 install scons

Examples:
  # Build all platforms
  ./scripts/build-all-platforms.sh

  # Rebuild godot-cpp and extensions
  ./scripts/build-all-platforms.sh --clean

  # Build just Windows
  ./scripts/build-all-platforms.sh --windows-only

  # Build Linux and Windows (skip Web)
  ./scripts/build-all-platforms.sh --linux-only --windows-only
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) DO_CLEAN=true; shift ;;
        --linux-only) LINUX_ONLY=true; shift ;;
        --windows-only) WINDOWS_ONLY=true; shift ;;
        --web-only) WEB_ONLY=true; shift ;;
        --help) show_help; exit 0 ;;
        *) error "Unknown option: $1\nRun with --help for usage" ;;
    esac
done

# If no specific platform selected, build all
if [ "$LINUX_ONLY" = false ] && [ "$WINDOWS_ONLY" = false ] && [ "$WEB_ONLY" = false ]; then
    LINUX_ONLY=true
    WINDOWS_ONLY=true
    WEB_ONLY=true
fi

log "SpaceWheat Multi-Platform Native Builder"
echo ""
echo "  Build targets:"
echo "    Linux:   $LINUX_ONLY"
echo "    Windows: $WINDOWS_ONLY"
echo "    Web:     $WEB_ONLY"
echo "    Clean:   $DO_CLEAN"
echo ""

# Emscripten lives in its own SDK tree and is not on PATH until activated. Do it
# HERE — before the prerequisite check that looks for emcc — because the check
# and the activation must not disagree. They used to: activation happened twice,
# further down inside the build blocks, so a clean shell always failed the check
# first and reported "Emscripten not found" on a machine where it was installed
# and working. That false negative is why the web channel was written off as
# unbuildable.
if [ "$WEB_ONLY" = true ] && [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # Activate the PINNED version, not whatever was last used. Activation is
    # what rewrites .emscripten and the PATH that emsdk_env.sh then exports;
    # sourcing alone inherits whatever the tree was left on.
    ( cd "$HOME/emsdk" && ./emsdk activate "$SW_EMSDK_VERSION" ) >/dev/null 2>&1 \
        || error "emsdk $SW_EMSDK_VERSION is not installed.\nRun: cd ~/emsdk && ./emsdk install $SW_EMSDK_VERSION"
    # emsdk_env.sh is chatty and returns nonzero under `set -e` on some versions.
    source "$HOME/emsdk/emsdk_env.sh" >/dev/null 2>&1 || true
fi

# Check prerequisites
log "Checking prerequisites..."

if [ "$LINUX_ONLY" = true ]; then
    command -v g++ >/dev/null 2>&1 || error "g++ not found. Run: sudo apt-get install build-essential"
fi

if [ "$WINDOWS_ONLY" = true ]; then
    command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1 || error "MinGW not found. Run: sudo apt-get install mingw-w64"
fi

if [ "$WEB_ONLY" = true ]; then
    command -v emcc >/dev/null 2>&1 || error "Emscripten not found. Run: source ~/emsdk/emsdk_env.sh"
    # Verify the pin actually took. Refuse to build against the wrong toolchain
    # rather than emit a wasm that loads and then dies mid-game.
    SW_EMCC_ACTIVE="$(emcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    if [ "$SW_EMCC_ACTIVE" != "$SW_EMSDK_VERSION" ]; then
        error "Emscripten $SW_EMCC_ACTIVE is active, but the web export template needs exactly $SW_EMSDK_VERSION.\nA mismatched side module links, loads, and then aborts on an undefined libc++ symbol the first time a farm boots.\nRun: cd ~/emsdk && ./emsdk install $SW_EMSDK_VERSION && ./emsdk activate $SW_EMSDK_VERSION"
    fi
    success "Emscripten $SW_EMCC_ACTIVE (pinned)"
fi

command -v scons >/dev/null 2>&1 || error "SCons not found. Run: pip3 install scons"

success "All prerequisites found"

# Clean godot-cpp if requested
if [ "$DO_CLEAN" = true ]; then
    log "Cleaning godot-cpp..."
    cd "$GODOT_CPP_DIR"
    rm -rf bin/
    success "godot-cpp cleaned"
fi

# Build godot-cpp for requested platforms
log "Building godot-cpp..."

cd "$GODOT_CPP_DIR"

GODOT_CPP_INPUTS=(SConstruct src include gen)

if [ "$LINUX_ONLY" = true ]; then
    if [ "$DO_CLEAN" = true ] || sw_output_is_stale "bin/libgodot-cpp.linux.template_release.x86_64.a" "${GODOT_CPP_INPUTS[@]}"; then
        log "Building godot-cpp for Linux..."
        scons platform=linux target=template_release -j$(nproc)
        success "godot-cpp Linux built"
    else
        success "godot-cpp Linux already built (cached)"
    fi
fi

if [ "$WINDOWS_ONLY" = true ]; then
    if [ "$DO_CLEAN" = true ] || sw_output_is_stale "bin/libgodot-cpp.windows.template_release.x86_64.a" "${GODOT_CPP_INPUTS[@]}"; then
        log "Building godot-cpp for Windows..."
        scons platform=windows target=template_release use_mingw=yes -j$(nproc)
        success "godot-cpp Windows built"
    else
        success "godot-cpp Windows already built (cached)"
    fi
fi

if [ "$WEB_ONLY" = true ]; then
    # Source staleness alone is not enough for web: the toolchain is an input.
    # A cached .a built by a different emsdk is exactly the bug this pin exists
    # to prevent, so a toolchain change invalidates the cache like a source edit.
    SW_CPP_EMSTAMP="bin/.emsdk-version"
    SW_CPP_TOOLCHAIN_CHANGED=false
    [ "$(cat "$SW_CPP_EMSTAMP" 2>/dev/null)" = "$SW_EMSDK_VERSION" ] || SW_CPP_TOOLCHAIN_CHANGED=true

    if [ "$DO_CLEAN" = true ] || [ "$SW_CPP_TOOLCHAIN_CHANGED" = true ] || sw_output_is_stale "bin/libgodot-cpp.web.template_release.wasm32.a" "${GODOT_CPP_INPUTS[@]}"; then
        if [ "$SW_CPP_TOOLCHAIN_CHANGED" = true ]; then
            log "Emscripten pin is $SW_EMSDK_VERSION; cached godot-cpp web build does not match. Rebuilding."
            rm -f bin/libgodot-cpp.web.template_release.wasm32.a
        fi
        log "Building godot-cpp for Web..."
        scons platform=web target=template_release -j$(nproc)
        mkdir -p bin && printf '%s\n' "$SW_EMSDK_VERSION" > "$SW_CPP_EMSTAMP"
        success "godot-cpp Web built"
    else
        success "godot-cpp Web already built (cached)"
    fi
fi

# Copy platform-specific static libraries into native/lib so the local and
# release build paths consume the same inputs.
mkdir -p "$NATIVE_DIR/lib"

if [ "$LINUX_ONLY" = true ] && [ -f "$GODOT_CPP_DIR/bin/libgodot-cpp.linux.template_release.x86_64.a" ]; then
    cp "$GODOT_CPP_DIR/bin/libgodot-cpp.linux.template_release.x86_64.a" \
       "$NATIVE_DIR/lib/libgodot-cpp.linux.template_release.x86_64.a"
fi

if [ "$WINDOWS_ONLY" = true ] && [ -f "$GODOT_CPP_DIR/bin/libgodot-cpp.windows.template_release.x86_64.a" ]; then
    cp "$GODOT_CPP_DIR/bin/libgodot-cpp.windows.template_release.x86_64.a" \
       "$NATIVE_DIR/lib/libgodot-cpp.windows.template_release.x86_64.a"
fi

if [ "$WEB_ONLY" = true ] && [ -f "$GODOT_CPP_DIR/bin/libgodot-cpp.web.template_release.wasm32.a" ]; then
    cp "$GODOT_CPP_DIR/bin/libgodot-cpp.web.template_release.wasm32.a" \
       "$NATIVE_DIR/lib/libgodot-cpp.web.template_release.wasm32.a"
fi

# Build SpaceWheat extensions
cd "$NATIVE_DIR"

NATIVE_INPUTS=(src include Makefile Makefile.windows)

if [ "$LINUX_ONLY" = true ]; then
    log "Building Linux extension..."
    if [ "$DO_CLEAN" = true ] || sw_output_is_stale "bin/linux/libquantummatrix.linux.template_release.x86_64.so" "${NATIVE_INPUTS[@]}" "lib/libgodot-cpp.linux.template_release.x86_64.a"; then
        make clean >/dev/null 2>&1 || true
        make -j$(nproc)
    else
        success "Linux extension already built (cached)"
    fi
    if command -v strip >/dev/null 2>&1; then
        strip --strip-unneeded bin/linux/libquantummatrix.linux.template_release.x86_64.so || true
    fi
    if [ -f "bin/linux/libquantummatrix.linux.template_release.x86_64.so" ]; then
        SIZE=$(ls -lh bin/linux/libquantummatrix.linux.template_release.x86_64.so | awk '{print $5}')
        success "Linux extension built ($SIZE)"
    else
        error "Linux build failed"
    fi
fi

if [ "$WINDOWS_ONLY" = true ]; then
    log "Building Windows extension..."
    if [ "$DO_CLEAN" = true ] || sw_output_is_stale "bin/windows/libquantummatrix.windows.template_release.x86_64.dll" "${NATIVE_INPUTS[@]}" "lib/libgodot-cpp.windows.template_release.x86_64.a"; then
        make -f Makefile.windows -j$(nproc)
    else
        success "Windows extension already built (cached)"
    fi
    if command -v x86_64-w64-mingw32-strip >/dev/null 2>&1; then
        x86_64-w64-mingw32-strip --strip-unneeded bin/windows/libquantummatrix.windows.template_release.x86_64.dll || true
        x86_64-w64-mingw32-strip --strip-unneeded bin/windows/libquantummatrix.windows.template_debug.x86_64.dll || true
    fi

    if [ -f "bin/windows/libquantummatrix.windows.template_release.x86_64.dll" ]; then
        SIZE=$(ls -lh bin/windows/libquantummatrix.windows.template_release.x86_64.dll | awk '{print $5}')
        success "Windows extension built ($SIZE)"
    else
        error "Windows build failed"
    fi
fi

if [ "$WEB_ONLY" = true ]; then
    log "Building Web extension (WASM)..."
    mkdir -p bin/web

    SW_EXT_EMSTAMP="bin/web/.emsdk-version"
    SW_EXT_TOOLCHAIN_CHANGED=false
    [ "$(cat "$SW_EXT_EMSTAMP" 2>/dev/null)" = "$SW_EMSDK_VERSION" ] || SW_EXT_TOOLCHAIN_CHANGED=true

    if [ "$DO_CLEAN" = true ] || [ "$SW_EXT_TOOLCHAIN_CHANGED" = true ] || sw_output_is_stale "bin/web/libquantummatrix.wasm" "${NATIVE_INPUTS[@]}" "lib/libgodot-cpp.web.template_release.wasm32.a"; then
        if [ "$SW_EXT_TOOLCHAIN_CHANGED" = true ]; then
            log "Emscripten pin is $SW_EMSDK_VERSION; cached web extension does not match. Rebuilding."
        fi
        # find(1) instead of src/*/*.cpp: subdirs hold only build artifacts, so the
        # glob stays literal and em++ hard-fails on the phantom input.
        # -pthread: must match the shipped engine variant (thread_support=true in the
        # web preset). A nothreads side module inside a shared-memory engine is an ABI
        # mismatch Godot refuses at load ("No GDExtension library found ... web.wasm32").
        em++ -std=c++17 -O3 -pthread -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
        -I./include \
        -I./include/godot_cpp \
        -I./include/gdextension \
        -DWEB_ENABLED -DGDEXTENSION -DSPACEWHEAT_WITH_GODOT -DSPACEWHEAT_WEB_BUILD \
        $(find src -name '*.cpp') \
        ./lib/libgodot-cpp.web.template_release.wasm32.a \
        -o bin/web/libquantummatrix.wasm || { error "em++ web build failed"; exit 1; }
        printf '%s\n' "$SW_EMSDK_VERSION" > "$SW_EXT_EMSTAMP"
    fi

    if [ -f "bin/web/libquantummatrix.wasm" ]; then
        SIZE=$(ls -lh bin/web/libquantummatrix.wasm | awk '{print $5}')
        success "Web extension built ($SIZE)"
        warn "Web extension build is enabled, but browser/runtime validation is still required before release."
    else
        error "Web build failed"
    fi
fi

# Summary
log "Build Summary:"
echo ""

if [ "$LINUX_ONLY" = true ] && [ -f "bin/linux/libquantummatrix.linux.template_release.x86_64.so" ]; then
    SIZE=$(ls -lh bin/linux/libquantummatrix.linux.template_release.x86_64.so | awk '{print $5}')
    echo "  ✅ Linux:   bin/linux/libquantummatrix.linux.template_release.x86_64.so ($SIZE)"
fi

if [ "$WINDOWS_ONLY" = true ] && [ -f "bin/windows/libquantummatrix.windows.template_release.x86_64.dll" ]; then
    SIZE=$(ls -lh bin/windows/libquantummatrix.windows.template_release.x86_64.dll | awk '{print $5}')
    echo "  ✅ Windows: bin/windows/libquantummatrix.windows.template_release.x86_64.dll ($SIZE)"
fi

if [ "$WEB_ONLY" = true ] && [ -f "bin/web/libquantummatrix.wasm" ]; then
    SIZE=$(ls -lh bin/web/libquantummatrix.wasm | awk '{print $5}')
    echo "  ✅ Web:     bin/web/libquantummatrix.wasm ($SIZE)"
fi

echo ""
success "All requested platforms built successfully!"
echo ""

if [ "$WINDOWS_ONLY" = true ] || [ "$WEB_ONLY" = true ]; then
    echo "Next steps:"
    echo "  1. Verify quantum_matrix.gdextension points at the built platform libraries"
    echo "  2. Export game for each platform:"
    if [ "$LINUX_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Linux Desktop\" releases/linux/game.x86_64"
    fi
    if [ "$WINDOWS_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Windows Desktop\" releases/windows/game.exe"
    fi
    if [ "$WEB_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Web\" releases/web/index.html"
    fi
    echo "  3. Test builds:"
    if [ "$WINDOWS_ONLY" = true ]; then
        echo "     wine releases/windows/game.exe"
    fi
    if [ "$WEB_ONLY" = true ]; then
        echo "     python3 scripts/serve-web-local.py releases/web --port 8000"
    fi
    echo ""
fi
