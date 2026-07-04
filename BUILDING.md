# Building SpaceWheat from Source

This guide will help you build SpaceWheat locally. If you're working with an LLM assistant (like Claude, ChatGPT, etc.), they can help you through each step.

---

## Quick Start (Linux)

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y build-essential git python3 python3-pip scons

# Clone repository
git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
cd SpaceWheat

# Build C++ extension
cd godot-cpp
scons platform=linux target=template_release -j$(nproc)
cd ../native
make -j$(nproc)

# Run the current game entry scene
godot --path .
```

---

## Prerequisites

### All Platforms
- **Godot Engine 4.5+** - [Download from godotengine.org](https://godotengine.org/download/)
- **Git** - For cloning the repository
- **Python 3.8+** - Required by SCons build system
- **SCons 4.0+** - Build tool (`pip install scons`)

### Linux
```bash
sudo apt-get install build-essential git python3 python3-pip scons
```

### Windows
- **Visual Studio 2019+** with C++ Desktop Development
- **MinGW-w64** (alternative to Visual Studio)
- **Python 3.8+** from python.org
- **SCons**: `pip install scons`

### macOS
```bash
brew install python scons
xcode-select --install  # For C++ compiler
```

---

## Step-by-Step Build Instructions

### 1. Clone Repository with Submodules

The repository includes `godot-cpp` as a submodule, which is required for building the native C++ extension.

```bash
git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
cd SpaceWheat
```

**If you forgot `--recurse-submodules`:**
```bash
git submodule update --init --recursive
```

### 2. Build godot-cpp (One-time Setup)

This step takes ~5-10 minutes. The output will be cached and reused.

#### Linux:
```bash
cd godot-cpp
scons platform=linux target=template_release -j$(nproc)
cd ..
```

#### Windows (Visual Studio):
```bash
cd godot-cpp
scons platform=windows target=template_release -j%NUMBER_OF_PROCESSORS%
cd ..
```

#### Windows (MinGW):
```bash
cd godot-cpp
scons platform=windows target=template_release use_mingw=yes -j%NUMBER_OF_PROCESSORS%
cd ..
```

#### macOS:
```bash
cd godot-cpp
scons platform=macos target=template_release -j$(sysctl -n hw.ncpu)
cd ..
```

**Expected output:** `bin/libgodot-cpp.{platform}.template_release.{arch}.a` (~100-200MB)

### 3. Build SpaceWheat Native Extension

The native extension provides high-performance quantum simulation using C++.

#### Linux:
```bash
cd native
make -j$(nproc)
```

**Expected output:** `bin/linux/libquantummatrix.linux.template_release.x86_64.so` (~1.7MB)

#### Windows (Visual Studio):
```bash
cd native
# Visual Studio support is not the checked-in native path yet.
# Build godot-cpp with MSVC if needed, but use the MinGW lane below for the
# actual SpaceWheat DLL until an MSVC-native build file lands in-repo.
```

#### Windows (MinGW):
```bash
cd native
make -f Makefile.windows -j$(nproc)
```

#### macOS:
```bash
cd native
# TODO: Add macOS build commands
```

### 4. Run the Game

#### Option A: Run in Godot Editor
```bash
godot --path . project.godot
```

#### Option B: Run Directly (if you have an export)
```bash
# Linux
./exports/SpaceWheat.x86_64

# Windows
exports\SpaceWheat.exe

# Web
cd exports && python3 ../scripts/serve-web-local.py . --port 8000
# Visit http://localhost:8000/SpaceWheat.html
```

---

## Exporting Release Builds

### Current Desktop Workflow
```bash
./scripts/build-desktop-local.sh --install-templates
./scripts/package-desktop-builds.sh --version v0.1.0
./scripts/deploy-windows-desktop.sh
./scripts/build-web-local.sh --install-templates
```

**Note:** Export presets are configured in `export_presets.cfg`.

- Windows desktop exports ship with the native DLL path and should be deployed through the shared desktop workflow.
- Web export is currently experimental, but the preset is now wired for native WASM GDExtension loading.
- The remaining gap is browser/runtime validation, not basic extension-path configuration.

### Manual Exports

Linux:
```bash
godot --headless --export-release "Linux Desktop" exports/SpaceWheat.x86_64
```

Windows:
```bash
godot --headless --export-release "Windows Desktop" exports/SpaceWheat.exe
```

Web:
```bash
godot --headless --export-release "Web" exports/SpaceWheat.html
```

---

## Troubleshooting

### "scons: command not found"
**Solution:** Install SCons with pip:
```bash
pip install scons
# or
pip3 install scons
```

### "fatal error: Python.h: No such file or directory"
**Solution:** Install Python development headers:
```bash
# Debian/Ubuntu
sudo apt-get install python3-dev

# Fedora/RHEL
sudo dnf install python3-devel

# macOS
brew install python
```

### godot-cpp build fails with "cl.exe not found"
**Solution (Windows):** Install Visual Studio 2019+ with C++ Desktop Development, or use MinGW:
```bash
scons platform=windows target=template_release use_mingw=yes
```

### Native extension not loading
**Check:**
1. Extension file exists: `native/bin/{platform}/libquantummatrix.*.so` or `.dll`
2. `quantum_matrix.gdextension` points to correct paths
3. Godot console shows: "GDExtension loaded successfully" (not "falling back to GDScript")

**Debug:** Open the project with `./scripts/launch-linux-editor.sh` and, if you want a saved log, add `--log-file /tmp/spacewheat-linux-editor.log`.

### Game runs but is very slow
**Likely causes:** Native extension failed to load, or the renderer fell back to a software path

**Solution:** Build the native extension (step 3), verify it loads, and confirm the runtime is not using a software renderer.

### Export fails with "Export preset not found"
**Solution:** Open the project in Godot Editor once to generate export presets, or copy `export_presets.cfg` from repository.

---

## Performance Optimization

### Release vs Debug Builds

**Debug builds** (default):
- Slower execution
- Include debug symbols
- Useful for development

**Release builds** (optimized):
- 2-5× faster
- Smaller file size
- For distribution

**Build release extension:**
```bash
cd godot-cpp
scons platform=linux target=template_release -j$(nproc)
cd ../native
make clean && make -j$(nproc)
```

### Compiler Optimization Flags

The Makefile already includes optimization flags:
- `-O2` - Level 2 optimization (balanced)
- `-march=x86-64` - Generic x86-64 compatibility

**For maximum performance** (may break compatibility):
```bash
# Edit native/Makefile and change:
CXXFLAGS += -O3 -march=native -flto
```

---

## Platform-Specific Notes

### Linux / WSL2

**WSL2 Graphics Setup:**
```bash
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0
```

**If you get "libGL error":**
```bash
export LIBGL_ALWAYS_SOFTWARE=1
```

### Windows

**Native extension build requires:**
- Visual Studio 2019+ with C++ Desktop Development
- OR MinGW-w64 (lighter alternative)

**Without C++ build tools:** The project can still boot in the pure GDScript path, but Windows shipping now expects the native DLL path.

### macOS

**Apple Silicon (M1/M2):**
```bash
scons platform=macos arch=arm64 target=template_release
```

**Intel:**
```bash
scons platform=macos arch=x86_64 target=template_release
```

**Universal Binary (both architectures):**
```bash
scons platform=macos arch=universal target=template_release
```

---

## Build Verification

After building, verify everything works:

```bash
# Check native extension exists
ls -lh native/bin/linux/*.so     # Linux
dir native\bin\windows\*.dll     # Windows
ls -lh native/bin/macos/*.dylib  # macOS

# Check godot-cpp library exists
ls -lh godot-cpp/bin/libgodot-cpp.*.a

# Run game and check console for:
godot --path . project.godot --verbose
# Look for: "GDExtension loaded successfully: QuantumMatrix"
```

---

## Getting Help

### With LLM Assistants

If you're using an LLM (Claude, ChatGPT, etc.) to help you build:

1. **Share your platform:** "I'm on Windows 11 / Ubuntu 22.04 / macOS 14"
2. **Share the error:** Copy/paste the full error message
3. **Ask specific questions:** "How do I install SCons on Windows?"

Example prompts:
- "Help me build SpaceWheat on Ubuntu 22.04"
- "I'm getting 'scons: command not found' on Windows"
- "The native extension won't load, what should I check?"

### Community Support

- **GitHub Issues:** https://github.com/AQuantumArchitect/SpaceWheat/issues
- **Discussions:** https://github.com/AQuantumArchitect/SpaceWheat/discussions
- **Discord:** (Add your Discord link)

---

## Development Setup

### Recommended Editor Setup

**For GDScript:**
- Use Godot's built-in script editor
- Or: VSCode with "Godot Tools" extension

**For C++ (native extension):**
- VSCode with "C/C++" extension
- CLion (JetBrains IDE)
- Visual Studio (Windows)

### Hot Reload

Godot supports hot-reloading GDScript changes, but C++ changes require:
1. Rebuild: `cd native && make -j$(nproc)`
2. Restart Godot editor

### Running Tests

```bash
# Run the full quantum physics suite (142 tests)
bash run_quantum_gate_tests.sh

# Run a specific suite directly
godot --headless --script tests/test_gate_exact_states.gd
godot --headless --script tests/test_2q_gate_embed.gd
```

---

## Build Artifacts

After a successful build, you should have:

```
SpaceWheat/
├── godot-cpp/
│   └── bin/
│       └── libgodot-cpp.linux.template_release.x86_64.a  # ~150MB
├── native/
│   ├── bin/
│   │   └── linux/
│   │       └── libquantummatrix.linux.template_release.x86_64.so  # ~1.7MB
│   └── lib/
│       └── libgodot-cpp.linux.template_release.x86_64.a  # (copy)
└── exports/  # (after export)
    └── SpaceWheat.x86_64  # ~374MB
```

---

## Clean Build

If you encounter build issues, try a clean build:

```bash
# Clean godot-cpp
cd godot-cpp
scons --clean
rm -rf bin/

# Clean native extension
cd ../native
make clean
rm -rf bin/ lib/

# Rebuild from scratch
cd ../godot-cpp
scons platform=linux target=template_release -j$(nproc)
cd ../native
make -j$(nproc)
```

---

## Contributing Build Improvements

If you improve the build process (especially for Windows/macOS), please submit a PR!

**Needed:**
- Windows native build instructions (Visual Studio + MinGW)
- macOS native build instructions
- Cross-compilation scripts (Linux → Windows)
- Docker build environment

---

## License

SpaceWheat is open source. See [LICENSE](LICENSE) for details.

---

**Last Updated:** 2026-02-11
**Godot Version:** 4.5.stable
**Supported Platforms:** Linux desktop, Windows desktop, experimental Web export
