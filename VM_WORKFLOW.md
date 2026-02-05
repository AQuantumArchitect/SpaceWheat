# VM Cross-Platform Build Workflow

Quick reference for building SpaceWheat on Linux VM for Windows and Web distribution.

## First Time Setup (30 minutes)

```bash
# Clone repository
git clone --recursive git@github.com:AQuantumArchitect/SpaceWheat.git
cd SpaceWheat

# Run automated setup (installs MinGW, Emscripten, Godot, Wine)
./scripts/setup-vm-cross-compile.sh

# Reload shell
source ~/.bashrc
```

## Build All Platforms

```bash
cd ~/SpaceWheat

# Build Linux, Windows, and Web (first time: ~25 min, incremental: ~2 min)
./scripts/build-all-platforms.sh
```

**Output:**
- `native/bin/linux/libquantummatrix.linux.template_release.x86_64.so` (1.7MB)
- `native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll` (1.5MB)
- `native/bin/web/libquantummatrix.wasm` (800KB)

## Export Game for Each Platform

```bash
# Linux
mkdir -p releases/linux
godot --headless --export-release "Linux Desktop" releases/linux/spacewheat-linux.x86_64

# Windows
mkdir -p releases/windows
godot --headless --export-release "Windows Desktop" releases/windows/spacewheat-windows.exe

# Web
mkdir -p releases/web
godot --headless --export-release "Web" releases/web/index.html
```

## Test Builds

```bash
# Test Windows build with Wine
wine releases/windows/spacewheat-windows.exe

# Test web build
python3 -m http.server -d releases/web 8000
# Open browser to http://VM_IP:8000
# Check browser console (F12) for native extension loading
```

## Package for Distribution

```bash
cd ~/SpaceWheat/releases

# Linux tarball
cd linux
tar -czf ../spacewheat-linux-v0.1.0.tar.gz .
cd ..

# Windows zip
cd windows
zip -r ../spacewheat-windows-v0.1.0.zip .
cd ..

# Web is already ready (upload entire web/ folder to itch.io)
```

## Incremental Builds (After Code Changes)

```bash
# If only GDScript changed (no C++ changes)
godot --headless --export-release "Linux Desktop" releases/linux/game.x86_64
godot --headless --export-release "Windows Desktop" releases/windows/game.exe
godot --headless --export-release "Web" releases/web/index.html

# If C++ changed
./scripts/build-all-platforms.sh  # Rebuild native libs (~2 min)
# Then export as above
```

## Build Options

```bash
# Build specific platforms
./scripts/build-all-platforms.sh --linux-only
./scripts/build-all-platforms.sh --windows-only
./scripts/build-all-platforms.sh --web-only

# Force rebuild godot-cpp (if submodule updated)
./scripts/build-all-platforms.sh --clean

# Help
./scripts/build-all-platforms.sh --help
```

## Troubleshooting

### "emcc not found"
```bash
source ~/emsdk/emsdk_env.sh
# Or reload shell: source ~/.bashrc
```

### Web build shows errors in browser console
Eigen library may have WASM compatibility issues. If web build fails:

1. Edit `quantum_matrix.gdextension`
2. Comment out: `# web.wasm32 = "res://native/bin/web/libquantummatrix.wasm"`
3. Re-export web build (will use GDScript fallback - slower but functional)

### Windows build crashes in Wine
Check Wine output for specific errors. Most common issues:
- Missing DLL dependencies (should be statically linked)
- Different Windows version in Wine

### Performance is slow
Make sure native extensions loaded:
- Check game logs for "Native acceleration enabled"
- If using fallback, you'll see "Using GDScript fallback" (4000× slower)

## File Sizes

| Platform | Extension Size | Game Export Size |
|----------|----------------|------------------|
| Linux | ~1.7MB .so | ~60-80MB |
| Windows | ~1.5MB .dll | ~70-90MB |
| Web | ~800KB .wasm | ~50-60MB (compressed) |

## Performance Comparison

| Platform | With Native | GDScript Fallback |
|----------|-------------|-------------------|
| Linux | 100% (baseline) | 0.025% (4000× slower) |
| Windows | 100% | 0.025% |
| Web | 90-100% | 0.025% |

**Native extensions are REQUIRED for acceptable performance.**

## Complete Workflow Example

```bash
# 1. Make code changes on dev machine, commit and push
git add .
git commit -m "Add new feature"
git push

# 2. On VM, pull changes
cd ~/SpaceWheat
git pull

# 3. If C++ changed, rebuild extensions
./scripts/build-all-platforms.sh  # ~2 min

# 4. Export all platforms
godot --headless --export-release "Linux Desktop" releases/linux/game.x86_64
godot --headless --export-release "Windows Desktop" releases/windows/game.exe
godot --headless --export-release "Web" releases/web/index.html

# 5. Test
wine releases/windows/game.exe  # Quick Windows test

# 6. Package
cd releases/linux && tar -czf ../spacewheat-linux-v0.1.1.tar.gz . && cd ../..
cd releases/windows && zip -r ../spacewheat-windows-v0.1.1.zip . && cd ../..

# 7. Upload to itch.io
# - Linux: spacewheat-linux-v0.1.1.tar.gz
# - Windows: spacewheat-windows-v0.1.1.zip
# - Web: Upload entire releases/web/ folder
```

## Documentation

- Full guide: `BUILD_CROSS_PLATFORM.md`
- Linux native build: `BUILD_LINUX.md`
- Build script source: `scripts/build-all-platforms.sh`
- VM setup script: `scripts/setup-vm-cross-compile.sh`
