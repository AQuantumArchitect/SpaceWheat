# Cross-Platform GDExtension Guide

Status note as of 2026-04-24:
- Linux and Windows desktop are the active shipping path.
- The current Web export preset is now wired for `variant/extensions_support=true`.
- Web/WASM is still exploratory because there is no trusted browser smoke/perf lane yet.

## Current Status

**Working:** Linux native `.so`
**In progress:** Windows native `.dll` via MinGW cross-compile
**Optional later:** Web/WASM

---

## Windows Export

### Option 1: Cross-Compile from Linux (MinGW)

**Install MinGW:**
```bash
sudo apt-get install mingw-w64 g++-mingw-w64-x86-64
```

**Build Windows DLL:**
```bash
cd ~/ws/SpaceWheat/native

# Cross-compile for Windows
x86_64-w64-mingw32-g++ -std=c++17 -shared -fPIC -O2 \
  -I./include \
  -I./include/godot_cpp \
  -I./include/gdextension \
  -DWINDOWS_ENABLED -DGDEXTENSION \
  src/*.cpp \
  ./lib/libgodot-cpp.windows.template_release.x86_64.a \
  -o bin/windows/libquantummatrix.windows.template_release.x86_64.dll \
  -static-libgcc -static-libstdc++
```

**Problem:** You need `libgodot-cpp.windows.*.a` (Windows build of godot-cpp)

---

### Option 2: GitHub Actions (Recommended)

**Create `.github/workflows/build.yml`:**
```yaml
name: Build GDExtension

on: [push, pull_request]

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]

    steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Build godot-cpp
      run: |
        cd godot-cpp
        scons platform=${{ matrix.platform }} target=template_release

    - name: Build extension
      run: |
        cd native
        make

    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: extension-${{ matrix.os }}
        path: native/bin/*.so
```

This builds for **Linux, Windows, macOS** automatically on every commit.

---

### Option 3: Build on Windows Natively

**Install on Windows:**
1. Visual Studio 2022 (Community Edition)
2. CMake or scons
3. Clone your repo

**Build:**
```cmd
cd native
make  # (if you have make for Windows)
# OR manually compile with cl.exe (MSVC)
```

---

### Option 4: Do Not Ship Windows Without Native

This project should not ship a Windows build without the native DLL.

The GDScript fallback is too slow for real gameplay. Treat it as a development fallback only, not a distribution target.

---

## Web Export (itch.io)

### The Challenge

**GDExtensions on web are EXPERIMENTAL:**
- Need to compile C++ → WebAssembly (WASM)
- Requires Emscripten toolchain
- Limited threading support
- Eigen might not work fully

### Option 1: Defer Web Until Native Or Performance Is Proven Acceptable

Web is optional. Do not let it block Linux and Windows desktop shipping.

**In `.gdextension` file:**
```ini
[libraries]

linux.debug.x86_64 = "res://native/bin/libquantummatrix.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://native/bin/libquantummatrix.linux.template_release.x86_64.so"
# web.wasm32 = ... (omit this - uses GDScript)
```

If you revisit Web later, either:
1. ship a real WASM native module, or
2. prove with profiling that fallback performance is acceptable for the public build.

### Option 2: Compile to WASM (Advanced)

**Install Emscripten:**
```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

**Build godot-cpp for WASM:**
```bash
cd ~/ws/godot-cpp
scons platform=web target=template_release
```

**Build your extension for WASM:**
```bash
cd ~/ws/SpaceWheat/native
emcc -std=c++17 -O2 -s SIDE_MODULE=1 \
  -I./include \
  -I./include/godot_cpp \
  src/*.cpp \
  -o bin/libquantummatrix.wasm
```

**Add to `.gdextension`:**
```ini
web.wasm32 = "res://native/bin/libquantummatrix.wasm"
```

**Caveats:**
- Eigen might not fully work in WASM
- Multi-threading limited
- Larger download size
- Not all C++ features supported

---

## Recommended Strategy

### For Development
✅ **Linux:** Use native .so (fast, you have this)

### For Distribution

**Desktop (Windows/Linux):**
- Ship native libraries only
- Do not ship fallback-only Windows

**Web (itch.io):**
- Prefer desktop uploads to itch.io first
- Add a browser build later only if native WASM or acceptable measured fallback exists

**Mobile (Android/iOS):**
- Android: Build ARM64 .so
- iOS: Build .dylib for ARM64
- OR: GDScript fallback (easiest)

---

## Quick Setup for Multi-Platform

### 1. Update `.gdextension` for Optional Platforms

```ini
[configuration]
entry_symbol = "quantum_matrix_library_init"
compatibility_minimum = "4.1"

[libraries]

# Linux (you have this)
linux.debug.x86_64 = "res://native/bin/libquantummatrix.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://native/bin/libquantummatrix.linux.template_release.x86_64.so"

# Windows (required for shipping on Windows)
windows.debug.x86_64 = "res://native/bin/windows/libquantummatrix.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll"

# macOS (optional)
# macos.debug = "res://native/bin/libquantummatrix.macos.template_debug.framework"
# macos.release = "res://native/bin/libquantummatrix.macos.template_release.framework"

# Web (optional - WASM)
# web.wasm32 = "res://native/bin/libquantummatrix.wasm"

# Android (optional)
# android.debug.arm64 = "res://native/bin/libquantummatrix.android.template_debug.arm64.so"
# android.release.arm64 = "res://native/bin/libquantummatrix.android.template_release.arm64.so"
```

### 2. Export Settings in Godot

**For each platform:**
1. Project → Export → Add Platform
2. Select Windows/Web/etc.
3. If native lib missing → uses GDScript automatically
4. Export!

---

## Testing Strategy

### Web Export Test
```bash
cd ~/ws/SpaceWheat
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000
# Visit http://localhost:8000
```

**Expected:**
- ✅ Game loads
- ✅ Browser/runtime behavior is observable
- ⚠️ Current repo preset disables extensions, so this remains exploratory

### Windows Export Test (on Linux with Wine)
```bash
godot --headless --export-release "Windows Desktop" build/SpaceWheat.exe
wine build/SpaceWheat.exe  # (if wine installed)
```

---

## Performance Expectations

| Platform | Native? | Performance | Recommendation |
|----------|---------|-------------|----------------|
| **Linux** | ✅ Yes | 100% (1.7MB .so) | Ship native |
| **Windows** | ✅ Yes | 100% with .dll | Ship native |
| **macOS** | ⚠️ Optional | 100% with .dylib, 10% without | Ship GDScript |
| **Web** | ❌ Experimental | unknown until browser profiling exists | Do not ship yet |
| **Android** | ⚠️ Optional | 100% with .so, 10% without | Ship GDScript |
| **iOS** | ⚠️ Optional | 100% with .dylib, 10% without | Ship GDScript |

---

## My Recommendation

**For itch.io web release:**
1. Prefer desktop uploads first
2. Do not promise web until there is a browser smoke/perf lane
3. Treat any web build as experimental
4. Provide downloadable Linux/Windows builds with native libs

**For downloadable releases:**
1. Use GitHub Actions to build Windows/Mac/Linux
2. Or ship Linux and Windows with native desktop binaries

**Why:**
- Web users expect slower performance anyway
- WASM compilation is experimental and fragile
- Focus on gameplay, not build complexity

---

## Summary

✅ **What you have:** Fast Linux native build
✅ **What you need for Windows:** .dll (cross-compile OR GitHub Actions)
⚠️ **What you need for Web:** an explicit browser validation/performance lane

**Practical read:** desktop is real, web still needs proof.
