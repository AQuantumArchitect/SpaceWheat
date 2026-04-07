# Desktop Release Workflow

This is the current local release path for SpaceWheat desktop builds.

## 1. Install export templates once

```bash
./scripts/install-godot-export-templates.sh
```

## 2. Build local desktop exports

```bash
./scripts/build-desktop-local.sh --install-templates
```

This produces:

- `releases/local/windows-native/SpaceWheat.exe`
- `releases/local/linux-native/SpaceWheat.x86_64`

To copy the built folders onto the Windows filesystem for manual launch:

```bash
./scripts/build-desktop-local.sh --copy-to-windows
```

Default Windows staging folder:

- `C:\Games\SpaceWheat Builds\windows-native`
- `C:\Games\SpaceWheat Builds\linux-native`

## 3. Package archives

```bash
./scripts/package-desktop-builds.sh --version v0.1.0
```

This produces:

- `releases/packages/spacewheat-windows-v0.1.0.zip`
- `releases/packages/spacewheat-linux-v0.1.0.tar.gz`

## 4. Smoke test expectations

Windows:

- Launch `SpaceWheat.exe`
- Confirm the game starts and the native DLL is present beside the exe

Linux:

- Launch the exported binary, or headless smoke test with writable runtime dirs:

```bash
mkdir -p /tmp/spacewheat-runtime-home /tmp/spacewheat-runtime-config /tmp/spacewheat-runtime-data
HOME=/tmp/spacewheat-runtime-home \
XDG_CONFIG_HOME=/tmp/spacewheat-runtime-config \
XDG_DATA_HOME=/tmp/spacewheat-runtime-data \
./releases/local/linux-native/SpaceWheat.x86_64 --headless --quit-after 1
```

## Notes

- Release export presets now exclude test scenes and other dev-only roots.
- Windows native shipping is supported through MinGW cross-compilation in WSL.
- The `scripts/build-release.sh` path still exists for fresh-clone release builds, but `build-desktop-local.sh` is the faster path for iterating on the current checkout.
