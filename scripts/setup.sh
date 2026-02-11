#!/bin/bash
# setup.sh - Quick setup script for SpaceWheat
#
# This script helps you install prerequisites and build the game.
# Safe to run multiple times - it will skip steps that are already done.

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}▶${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; exit 1; }

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         SpaceWheat - Quick Setup Script                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
else
    warn "Unknown OS: $OSTYPE. Assuming Linux."
    OS="linux"
fi

log "Detected OS: $OS"

# Step 1: Check prerequisites
log "Checking prerequisites..."

# Check Git
if ! command -v git &> /dev/null; then
    error "Git not found. Please install git first."
fi
success "Git installed: $(git --version | head -1)"

# Check Python
if ! command -v python3 &> /dev/null; then
    warn "Python 3 not found. Installing..."
    if [ "$OS" = "linux" ]; then
        sudo apt-get update && sudo apt-get install -y python3 python3-pip
    elif [ "$OS" = "macos" ]; then
        brew install python3
    else
        error "Please install Python 3 manually: https://python.org"
    fi
fi
success "Python installed: $(python3 --version)"

# Check SCons
if ! command -v scons &> /dev/null; then
    warn "SCons not found. Installing..."
    pip3 install scons
    success "SCons installed"
else
    success "SCons installed: $(scons --version | head -1)"
fi

# Check compiler
if [ "$OS" = "linux" ]; then
    if ! command -v g++ &> /dev/null; then
        warn "g++ not found. Installing build-essential..."
        sudo apt-get install -y build-essential
    fi
    success "Compiler installed: $(g++ --version | head -1)"
elif [ "$OS" = "macos" ]; then
    if ! command -v clang &> /dev/null; then
        warn "Xcode Command Line Tools not found. Installing..."
        xcode-select --install
    fi
    success "Compiler installed: $(clang --version | head -1)"
fi

# Check Godot
if ! command -v godot &> /dev/null; then
    warn "Godot not found in PATH."
    echo ""
    echo "Please download Godot 4.5+ from: https://godotengine.org/download/"
    echo "After installing, add it to PATH or set GODOT_BIN environment variable."
    echo ""
    read -p "Press Enter when Godot is installed..."
fi

if command -v godot &> /dev/null; then
    GODOT_VERSION=$(godot --version 2>/dev/null | head -1)
    success "Godot installed: $GODOT_VERSION"
else
    warn "Godot still not found. You'll need to install it manually."
fi

# Step 2: Initialize submodules
log "Checking git submodules..."
if [ ! -f "godot-cpp/SConstruct" ]; then
    log "Initializing godot-cpp submodule..."
    git submodule update --init --recursive
    success "Submodules initialized"
else
    success "Submodules already initialized"
fi

# Step 3: Build godot-cpp
GODOT_CPP_LIB="godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a"
if [ "$OS" = "macos" ]; then
    GODOT_CPP_LIB="godot-cpp/bin/libgodot-cpp.macos.template_release.universal.a"
fi

if [ -f "$GODOT_CPP_LIB" ]; then
    success "godot-cpp already built"
else
    log "Building godot-cpp (this takes ~5-10 minutes)..."
    cd godot-cpp

    if [ "$OS" = "linux" ]; then
        scons platform=linux target=template_release -j$(nproc)
    elif [ "$OS" = "macos" ]; then
        scons platform=macos target=template_release -j$(sysctl -n hw.ncpu)
    else
        warn "Skipping godot-cpp build on Windows (requires Visual Studio or MinGW)"
        cd ..
        echo ""
        echo "For Windows build instructions, see BUILDING.md"
        exit 0
    fi

    cd ..
    success "godot-cpp built successfully"
fi

# Step 4: Build native extension
NATIVE_LIB="native/bin/linux/libquantummatrix.linux.template_release.x86_64.so"
if [ "$OS" = "macos" ]; then
    NATIVE_LIB="native/bin/macos/libquantummatrix.macos.template_release.universal.dylib"
fi

if [ -f "$NATIVE_LIB" ]; then
    success "Native extension already built"
else
    log "Building native extension..."
    cd native

    if [ "$OS" = "linux" ]; then
        make -j$(nproc)
    elif [ "$OS" = "macos" ]; then
        make -j$(sysctl -n hw.ncpu)
    fi

    cd ..
    success "Native extension built successfully"
fi

# Step 5: Verify build
log "Verifying build..."

if [ -f "$GODOT_CPP_LIB" ]; then
    GODOT_CPP_SIZE=$(du -h "$GODOT_CPP_LIB" | cut -f1)
    success "godot-cpp library: $GODOT_CPP_SIZE"
else
    warn "godot-cpp library not found"
fi

if [ -f "$NATIVE_LIB" ]; then
    NATIVE_SIZE=$(du -h "$NATIVE_LIB" | cut -f1)
    success "Native extension: $NATIVE_SIZE"
else
    warn "Native extension not found - game will run in GDScript fallback mode (slower)"
fi

# Done!
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Setup Complete!                                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "  1. Run the game in Godot editor:"
echo "     godot --path . project.godot"
echo ""
echo "  2. Or export a release:"
echo "     ./scripts/build-release.sh --platform linux --install"
echo ""
echo "  3. For more info, see BUILDING.md"
echo ""
