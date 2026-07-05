# Building SpaceWheat on Linux

This guide covers building SpaceWheat from source on a fresh Linux machine.

## Prerequisites

### Required Packages

```bash
# Ubuntu/Debian
sudo apt install -y git g++ make wget unzip

# Fedora/RHEL
sudo dnf install -y git gcc-c++ make wget unzip

# Arch
sudo pacman -S git gcc make wget unzip
```

### Godot 4.5

Download and install Godot 4.5 headless:

```bash
cd /tmp
wget https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip
unzip Godot_v4.5-stable_linux.x86_64.zip
sudo mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot

# Verify installation
godot --version
# Should output: 4.5.stable.official.876b29033
```

## Quick Start (Automated Build)

The easiest way to build a release:

```bash
# Clone repo with submodules
git clone --recursive git@github.com:AQuantumArchitect/SpaceWheat.git
cd SpaceWheat

# Build and install (handles everything automatically)
./scripts/build-linux-release.sh --clean --install

# Game installed to ~/games/SpaceWheat/
~/games/SpaceWheat/spacewheat-linux.x86_64
```

## Manual Build Process

If you prefer to build manually or need more control:

### 1. Clone Repository

```bash
git clone --recursive git@github.com:AQuantumArchitect/SpaceWheat.git
cd SpaceWheat
```

The `--recursive` flag automatically clones the godot-cpp submodule.

If you forgot `--recursive`:
```bash
git submodule update --init --recursive
```

### 2. Build godot-cpp Bindings

This is a one-time build that takes ~5 minutes:

```bash
cd godot-cpp
scons platform=linux target=template_release -j$(nproc)
cd ..
```

You should see output ending with:
```
scons: done building targets.
```

The compiled library will be at:
```
godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a
```

### 3. Build C++ Extension

```bash
cd native
make
cd ..
```

This compiles the quantum simulation engine (~1 minute). Output:
```
✓ Build complete: bin/linux/libquantummatrix.linux.template_release.x86_64.so
```

### 4. Test in Godot Editor (Optional)

```bash
godot --editor .
```

Run any of the test scenes to verify the build works.

### 5. Export Release Build

```bash
mkdir -p export
godot --headless --export-release "Linux Desktop" ./export/spacewheat-linux.x86_64
```

This creates a standalone executable at `export/spacewheat-linux.x86_64`.

### 6. Package Tarball (Optional)

```bash
mkdir -p releases/linux
cd export
tar -czf ../releases/linux/spacewheat-linux-v0.1.0.tar.gz .
cd ..
```

## Running the Game

### From Build Directory

```bash
./export/spacewheat-linux.x86_64
```

### From Install Directory (if using --install)

```bash
~/games/SpaceWheat/spacewheat-linux.x86_64
```

## Build Script Options

The automated build script supports several options:

```bash
# Build specific version
./scripts/build-linux-release.sh --version v0.2.0

# Force rebuild godot-cpp (use if submodule updated)
./scripts/build-linux-release.sh --clean

# Build and install to ~/games/SpaceWheat/
./scripts/build-linux-release.sh --install

# Skip C++ build (GDScript changes only)
./scripts/build-linux-release.sh --skip-cpp

# Skip export (just build C++ extension)
./scripts/build-linux-release.sh --skip-export

# Verbose output
./scripts/build-linux-release.sh --verbose

# Combine options
./scripts/build-linux-release.sh --clean --install --verbose
```

## Troubleshooting

### "godot: command not found"

Godot is not in your PATH. Either:
- Install godot to /usr/local/bin as shown above
- Or set GODOT_BIN environment variable:
```bash
export GODOT_BIN=/path/to/godot
./scripts/build-linux-release.sh
```

### "undefined symbol: gdextension_interface_*"

The C++ extension failed to link properly. Try:
```bash
cd native
make clean
make
cd ..
```

### "Submodule 'godot-cpp' not found"

You forgot to clone submodules:
```bash
git submodule update --init --recursive
```

### Export hangs or fails silently

Check export_presets.cfg exists:
```bash
ls -la export_presets.cfg
```

If missing, it should be in git. Try:
```bash
git pull origin main
```

### Build script fails at "Exporting game"

Try manual export to see full error:
```bash
godot --headless --export-release "Linux Desktop" ./export/test.x86_64 --verbose
```

## File Structure

```
SpaceWheat/
├── Core/                    # GDScript game logic
├── UI/                      # User interface
├── native/                  # C++ extension
│   ├── src/                 # C++ source files
│   ├── include/             # Headers (Eigen, godot-cpp)
│   ├── Makefile            # Build configuration
│   └── bin/linux/          # Compiled .so files (gitignored)
├── godot-cpp/              # Godot C++ bindings (submodule)
├── scripts/                # Build automation
│   └── build-linux-release.sh
├── quantum_matrix.gdextension  # GDExtension registration
├── export_presets.cfg      # Godot export configuration
└── project.godot           # Godot project file
```

## System Requirements

### Build Requirements
- Linux (kernel 4.4+)
- 2GB RAM minimum (4GB recommended for parallel builds)
- 500MB disk space (godot-cpp cache)
- Internet connection (first build only)

### Runtime Requirements
- Linux x86_64
- OpenGL 3.3+ (or software renderer like llvmpipe)
- 100MB disk space
- 512MB RAM minimum

## Additional Resources

- **Native Extension Documentation**: `native/README.md`
- **Cross-Platform Builds**: `native/CROSS_PLATFORM.md`
- **All Platform Builds**: `native/BUILD_ALL_PLATFORMS.md`
- **Godot Export Docs**: https://docs.godotengine.org/en/stable/tutorials/export/

## License

See LICENSE file in repository root.
