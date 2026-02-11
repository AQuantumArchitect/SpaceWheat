#!/bin/bash
# build-release.sh - Unified multi-platform release builder for SpaceWheat
#
# Usage:
#   ./scripts/build-release.sh --platform linux                # Build Linux
#   ./scripts/build-release.sh --platform windows --install    # Build Windows + install
#   ./scripts/build-release.sh --platform web                  # Build Web
#   ./scripts/build-release.sh --platform all --version v0.2.0 # Build all platforms
#
# This script:
#   1. Clones fresh repo to build directory
#   2. Builds godot-cpp (cached unless --clean) [Linux only]
#   3. Builds C++ extension [Linux only]
#   4. Exports game via Godot headless
#   5. Creates archive in releases/{platform}/
#   6. Optionally installs to ~/games/SpaceWheat*/

set -e

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
REPO_URL="https://github.com/AQuantumArchitect/SpaceWheat.git"
BUILD_DIR="$HOME/ws/tmp/SpaceWheat-build"
GODOT_CPP_CACHE="$HOME/ws/tmp/godot-cpp-cache"
GODOT_BIN="${GODOT_BIN:-godot}"

# Defaults
PLATFORM="linux"
VERSION="v0.1.0"
DO_INSTALL=false
DO_CLEAN=false
SKIP_CPP=false
SKIP_EXPORT=false
VERBOSE=false

# Platform-specific configuration (set after argument parsing)
PRESET_NAME=""
EXPORT_EXT=""
ARCHIVE_EXT=""
INSTALL_DIR=""
BUILD_NATIVE=false
RELEASE_DIR=""

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
SpaceWheat Unified Multi-Platform Release Builder

USAGE:
    build-release.sh [OPTIONS]

OPTIONS:
    --platform, -p PLATFORM Platform to build (linux, windows, web, all)
    --version, -v VERSION   Set release version (default: v0.1.0)
    --install, -i           Install to ~/games/SpaceWheat* after build
    --clean, -c             Force rebuild of godot-cpp (normally cached)
    --skip-cpp              Skip C++ build (use existing binaries)
    --skip-export           Skip Godot export (use existing export)
    --verbose               Show detailed output
    --help, -h              Show this help message

PLATFORMS:
    linux       Linux Desktop (x86_64) - Builds native C++ extension
    windows     Windows Desktop (x86_64) - Uses GDScript fallback
    web         Web (HTML5/WebAssembly) - Uses GDScript fallback
    all         Build all platforms sequentially

EXAMPLES:
    # Build Linux (with native extension)
    ./scripts/build-release.sh --platform linux --install

    # Build Windows (GDScript fallback)
    ./scripts/build-release.sh --platform windows --install

    # Build Web
    ./scripts/build-release.sh --platform web

    # Build all platforms with version tag
    ./scripts/build-release.sh --platform all --version v0.2.0

    # Quick rebuild (skip C++ if unchanged)
    ./scripts/build-release.sh --platform linux --skip-cpp --install

    # Full clean rebuild
    ./scripts/build-release.sh --platform linux --clean --install

ENVIRONMENT:
    GODOT_BIN       Path to Godot binary (default: godot)

OUTPUT:
    Linux:   ~/ws/SpaceWheat/releases/linux/spacewheat-linux-VERSION.tar.gz
    Windows: ~/ws/SpaceWheat/releases/windows/spacewheat-windows-VERSION.zip
    Web:     ~/ws/SpaceWheat/releases/web/spacewheat-web-VERSION.tar.gz

INSTALL PATHS:
    Linux:   ~/games/SpaceWheat/
    Windows: ~/games/SpaceWheat_Windows/
    Web:     (no install - run via HTTP server)

EOF
    exit 0
}

# ─────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
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
# Handle "all platforms" mode (recursive)
# ─────────────────────────────────────────────────────────────
if [ "$PLATFORM" = "all" ]; then
    log "Building all platforms..."
    echo ""

    # Build each platform sequentially
    for p in linux windows web; do
        log "═══════════════════════════════════════════════════════════════"
        log "Building platform: $p"
        log "═══════════════════════════════════════════════════════════════"

        # Recursive call with filtered arguments (remove --platform all)
        FILTERED_ARGS=()
        SKIP_NEXT=false
        for arg in "$@"; do
            if [ "$SKIP_NEXT" = true ]; then
                SKIP_NEXT=false
                continue
            fi
            if [ "$arg" = "--platform" ] || [ "$arg" = "-p" ]; then
                SKIP_NEXT=true
                continue
            fi
            FILTERED_ARGS+=("$arg")
        done

        "$0" --platform "$p" "${FILTERED_ARGS[@]}"
        echo ""
    done

    log "═══════════════════════════════════════════════════════════════"
    success "All platforms built successfully!"
    log "═══════════════════════════════════════════════════════════════"
    exit 0
fi

# ─────────────────────────────────────────────────────────────
# Set platform-specific configuration
# ─────────────────────────────────────────────────────────────
case "$PLATFORM" in
    linux)
        PRESET_NAME="Linux Desktop"
        EXPORT_EXT="x86_64"
        ARCHIVE_EXT="tar.gz"
        INSTALL_DIR="$HOME/games/SpaceWheat"
        BUILD_NATIVE=true  # Build C++ extension
        RELEASE_DIR="$HOME/ws/SpaceWheat/releases/linux"
        ;;
    windows)
        PRESET_NAME="Windows Desktop"
        EXPORT_EXT="exe"
        ARCHIVE_EXT="zip"
        INSTALL_DIR="$HOME/games/SpaceWheat_Windows"
        BUILD_NATIVE=false  # Skip C++ (use GDScript fallback or pre-built)
        RELEASE_DIR="$HOME/ws/SpaceWheat/releases/windows"
        ;;
    web)
        PRESET_NAME="Web"
        EXPORT_EXT="html"
        ARCHIVE_EXT="tar.gz"
        INSTALL_DIR=""  # Web doesn't install locally
        BUILD_NATIVE=false  # Skip C++ (use GDScript fallback or pre-built)
        RELEASE_DIR="$HOME/ws/SpaceWheat/releases/web"
        ;;
    *)
        error "Unknown platform: $PLATFORM (use: linux, windows, web, all)"
        ;;
esac

# ─────────────────────────────────────────────────────────────
# Validate environment
# ─────────────────────────────────────────────────────────────
log "Validating environment..."

if ! command -v $GODOT_BIN &> /dev/null; then
    error "Godot not found. Set GODOT_BIN or ensure 'godot' is in PATH."
fi

# Only require build tools for Linux native builds
if [ "$BUILD_NATIVE" = true ]; then
    if ! command -v scons &> /dev/null; then
        error "scons not found. Install with: pip install scons"
    fi

    if ! command -v g++ &> /dev/null; then
        error "g++ not found. Install build-essential."
    fi
fi

# Check for zip on Windows builds
if [ "$PLATFORM" = "windows" ] && ! command -v zip &> /dev/null; then
    error "zip not found. Install with: sudo apt-get install zip"
fi

GODOT_VERSION=$($GODOT_BIN --version 2>/dev/null | head -1)
success "Environment OK (Godot: $GODOT_VERSION)"

echo ""
echo "  Platform:    $PLATFORM"
echo "  Preset:      $PRESET_NAME"
echo "  Version:     $VERSION"
echo "  Install:     $DO_INSTALL"
echo "  Clean:       $DO_CLEAN"
echo "  Skip C++:    $SKIP_CPP"
echo "  Skip Export: $SKIP_EXPORT"
echo "  Native:      $BUILD_NATIVE"

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
# Step 2: Build godot-cpp (Linux only, with caching)
# ─────────────────────────────────────────────────────────────
if [ "$BUILD_NATIVE" = true ] && [ "$SKIP_CPP" = false ]; then
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
fi

# ─────────────────────────────────────────────────────────────
# Step 3: Build C++ extension (Linux only)
# ─────────────────────────────────────────────────────────────
if [ "$BUILD_NATIVE" = true ] && [ "$SKIP_CPP" = false ]; then
    log "Building C++ extension for $PLATFORM..."
    cd "$BUILD_DIR/native"
    make clean 2>/dev/null || true
    make -j$(nproc)

    SO_FILE=$(ls -1 bin/linux/*.so 2>/dev/null | grep -v debug | head -1)
    if [ -n "$SO_FILE" ]; then
        SO_SIZE=$(du -h "$SO_FILE" | cut -f1)
        success "C++ extension built: $SO_SIZE"
    else
        error "C++ extension build failed - no .so file found"
    fi
else
    if [ "$BUILD_NATIVE" = false ]; then
        warn "Skipping native build for $PLATFORM (using GDScript fallback or pre-built binaries)"
    else
        warn "Skipping C++ build (--skip-cpp)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 4: Export game with Godot
# ─────────────────────────────────────────────────────────────
EXPORT_DIR="$BUILD_DIR/export/SpaceWheat"

if [ "$SKIP_EXPORT" = true ]; then
    warn "Skipping Godot export (--skip-export)"
    if [ ! -d "$EXPORT_DIR" ]; then
        error "No existing export found. Remove --skip-export."
    fi
else
    log "Exporting game with Godot ($PRESET_NAME)..."
    cd "$BUILD_DIR"
    mkdir -p "$EXPORT_DIR"

    # Copy export preset from dev repo
    EXPORT_PRESET_SOURCE="$HOME/ws/SpaceWheat/export_presets.cfg"
    if [ -f "$EXPORT_PRESET_SOURCE" ]; then
        cp "$EXPORT_PRESET_SOURCE" "$BUILD_DIR/"
        debug "Copied export_presets.cfg from dev repo"
    else
        error "export_presets.cfg not found at $EXPORT_PRESET_SOURCE"
    fi

    # Import project first (generates .godot folder)
    debug "Importing project..."
    timeout 60 $GODOT_BIN --headless --import . 2>/dev/null || true

    # Export
    debug "Running export..."
    $GODOT_BIN --headless --export-release "$PRESET_NAME" "$EXPORT_DIR/SpaceWheat.$EXPORT_EXT" 2>&1 | grep -v "^$" || true

    # Verify export
    if [ "$PLATFORM" = "web" ]; then
        # Web exports create multiple files
        if [ ! -f "$EXPORT_DIR/SpaceWheat.html" ]; then
            error "Export failed - SpaceWheat.html not created. Check export preset."
        fi
    else
        if [ ! -f "$EXPORT_DIR/SpaceWheat.$EXPORT_EXT" ]; then
            error "Export failed - SpaceWheat.$EXPORT_EXT not created. Check export preset."
        fi
    fi

    success "Game exported ($PRESET_NAME)"
fi

# Copy C++ extension to export (Linux only)
if [ "$BUILD_NATIVE" = true ]; then
    log "Packaging C++ extension with export..."
    cp "$BUILD_DIR/native/bin/linux/"*.so "$EXPORT_DIR/" 2>/dev/null || warn "No .so files to copy"
fi

# ─────────────────────────────────────────────────────────────
# Step 5: Create platform-specific launch scripts and README
# ─────────────────────────────────────────────────────────────
log "Creating launch scripts and README..."

# Platform-specific launch script
if [ "$PLATFORM" = "windows" ]; then
    cat > "$EXPORT_DIR/launch.bat" << 'WINLAUNCH'
@echo off
cd /d "%~dp0"
SpaceWheat.exe %*
WINLAUNCH
    success "Created launch.bat"
elif [ "$PLATFORM" = "linux" ]; then
    cat > "$EXPORT_DIR/launch.sh" << 'LINUXLAUNCH'
#!/bin/bash
cd "$(dirname "$0")"
./SpaceWheat.x86_64 "$@"
LINUXLAUNCH
    chmod +x "$EXPORT_DIR/launch.sh"
    success "Created launch.sh"
fi

# Create README with platform-specific instructions
cat > "$EXPORT_DIR/README.md" << EOF
# SpaceWheat - Quantum Farm ($PLATFORM Build)

**Exported:** $(date +%Y-%m-%d)
**Version:** $VERSION
**Platform:** $PLATFORM
**Commit:** $COMMIT_HASH

---

## Running the Game

EOF

# Add platform-specific instructions
case "$PLATFORM" in
    linux)
        cat >> "$EXPORT_DIR/README.md" << 'EOF'
### Quick Start (Linux/WSL2)
```bash
cd ~/games/SpaceWheat
./launch.sh
```

Or run directly:
```bash
./SpaceWheat.x86_64
```

### WSL2 Graphics Setup
If running in WSL2, ensure WSLg is enabled:
```bash
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0
./SpaceWheat.x86_64
```
EOF
        ;;
    windows)
        cat >> "$EXPORT_DIR/README.md" << 'EOF'
### Quick Start (Windows)

**Option 1:** Double-click `SpaceWheat.exe` in File Explorer

**Option 2:** Run from command line:
```bash
cd ~/games/SpaceWheat_Windows
./SpaceWheat.exe
```

Or use the batch file:
```bash
./launch.bat
```

### Note: GDScript Fallback
This build uses GDScript fallback (no native C++ extension). Performance may be 10-100× slower than the Linux build with native extensions. For better performance, build the Windows native extension separately using MinGW cross-compilation.
EOF
        ;;
    web)
        cat >> "$EXPORT_DIR/README.md" << 'EOF'
### Quick Start (Web)

**Option 1:** Serve locally with Python:
```bash
cd ~/ws/SpaceWheat/releases/web/SpaceWheat
python3 -m http.server 8000
# Visit http://localhost:8000/SpaceWheat.html
```

**Option 2:** Serve with Node.js:
```bash
npx http-server . -p 8000
# Visit http://localhost:8000/SpaceWheat.html
```

**Option 3:** Deploy to web host (GitHub Pages, Netlify, etc.)

### Note: GDScript Fallback
This build uses GDScript fallback (no native WebAssembly extension). Performance may be slower than builds with native extensions. For better performance, build the Web native extension using Emscripten.

### Browser Compatibility
- Chrome 90+
- Firefox 88+
- Safari 14.1+
- Edge 90+
EOF
        ;;
esac

# Add common footer
cat >> "$EXPORT_DIR/README.md" << 'EOF'

---

## File Structure

```
SpaceWheat/
├── SpaceWheat.*        # Game executable/HTML
├── SpaceWheat.pck      # Game data (embedded or separate)
├── launch.*            # Platform-specific launcher
└── README.md           # This file
```

---

## Troubleshooting

### Game won't start
- Check console output for errors
- Verify Godot 4.x runtime dependencies installed
- For Linux: Ensure OpenGL/Vulkan drivers installed

### Performance issues
- Lower graphics settings in-game
- Close other applications
- For non-native builds: Consider building with native extensions

### Graphics glitches
- Update GPU drivers
- Try switching between OpenGL/Vulkan renderers
- For WSL2: Ensure WSLg is properly configured

---

## Support

- GitHub: https://github.com/AQuantumArchitect/SpaceWheat
- Issues: https://github.com/AQuantumArchitect/SpaceWheat/issues
- Discord: (Add your Discord link)

---

Built with ❤️ using Godot Engine 4.x
EOF

success "Created README.md"

# ─────────────────────────────────────────────────────────────
# Step 6: Create release archive
# ─────────────────────────────────────────────────────────────
log "Creating release archive..."
mkdir -p "$RELEASE_DIR"
ARCHIVE="$RELEASE_DIR/spacewheat-${PLATFORM}-${VERSION}.${ARCHIVE_EXT}"

cd "$BUILD_DIR/export"
if [ "$ARCHIVE_EXT" = "tar.gz" ]; then
    tar czf "$ARCHIVE" SpaceWheat/
elif [ "$ARCHIVE_EXT" = "zip" ]; then
    zip -r "$ARCHIVE" SpaceWheat/ >/dev/null
fi

ARCHIVE_SIZE=$(du -h "$ARCHIVE" | cut -f1)
success "Release created: $ARCHIVE ($ARCHIVE_SIZE)"

# ─────────────────────────────────────────────────────────────
# Step 7: Install (optional)
# ─────────────────────────────────────────────────────────────
if [ "$DO_INSTALL" = true ]; then
    if [ -z "$INSTALL_DIR" ]; then
        warn "Platform $PLATFORM does not support local installation (web build)"
    else
        log "Installing to $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        mkdir -p "$(dirname "$INSTALL_DIR")"

        if [ "$ARCHIVE_EXT" = "tar.gz" ]; then
            tar xzf "$ARCHIVE" -C "$(dirname "$INSTALL_DIR")"
        elif [ "$ARCHIVE_EXT" = "zip" ]; then
            unzip -q "$ARCHIVE" -d "$(dirname "$INSTALL_DIR")"
        fi

        # Verify
        if [ "$PLATFORM" = "web" ]; then
            if [ -f "$INSTALL_DIR/SpaceWheat.html" ]; then
                success "Installed to $INSTALL_DIR"
            else
                error "Installation verification failed"
            fi
        else
            if [ -f "$INSTALL_DIR/SpaceWheat.$EXPORT_EXT" ]; then
                success "Installed to $INSTALL_DIR"
            else
                error "Installation verification failed"
            fi
        fi
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
echo -e "\033[1;32m✓ SpaceWheat $PLATFORM $VERSION build complete!\033[0m"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Platform: $PLATFORM"
echo "  Archive:  $ARCHIVE"
echo "  Size:     $ARCHIVE_SIZE"
echo "  Commit:   $COMMIT_HASH"
echo ""

if [ "$DO_INSTALL" = true ] && [ -n "$INSTALL_DIR" ]; then
    echo "  Installed: $INSTALL_DIR"
    echo ""
    echo "  Run with:"
    case "$PLATFORM" in
        linux)
            echo "    $INSTALL_DIR/SpaceWheat.x86_64"
            echo "    # or"
            echo "    $INSTALL_DIR/launch.sh"
            ;;
        windows)
            echo "    $INSTALL_DIR/SpaceWheat.exe"
            echo "    # or"
            echo "    $INSTALL_DIR/launch.bat"
            ;;
    esac
    echo ""
fi

if [ "$PLATFORM" = "web" ]; then
    echo "  Serve web build:"
    echo "    cd $RELEASE_DIR && tar xzf $ARCHIVE"
    echo "    cd SpaceWheat && python3 -m http.server 8000"
    echo "    # Visit http://localhost:8000/SpaceWheat.html"
    echo ""
fi

echo "  Upload to GitHub Releases:"
echo "    gh release create $VERSION $ARCHIVE --title \"SpaceWheat $VERSION ($PLATFORM)\""
echo ""

if [ "$PLATFORM" != "web" ]; then
    echo "  Upload to itch.io (with butler):"
    echo "    butler push $ARCHIVE yourname/spacewheat:$PLATFORM"
    echo ""
fi

echo "════════════════════════════════════════════════════════════"
