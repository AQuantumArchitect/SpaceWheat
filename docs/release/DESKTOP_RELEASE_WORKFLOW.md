# Desktop Release Workflow

This is the current local release path for SpaceWheat desktop builds.

The runtime entry scene is `res://scenes/Main.tscn`.

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

To refresh the Windows staging folder from the built export:

```bash
./scripts/build-desktop-local.sh --copy-to-windows
```

Default Windows staging folder:

- `C:\Games\SpaceWheat Builds\windows-native`

To deploy that staged build into the player-facing Windows folder:

```bash
./scripts/deploy-windows-desktop.sh
```

Default player folder:

- `C:\Games\🌾🚀🌌SpaceWheat`

## 3. Package archives

```bash
./scripts/package-desktop-builds.sh --version v0.1.0
```

This produces:

- `releases/packages/spacewheat-windows-v0.1.0.zip`
- `releases/packages/spacewheat-linux-v0.1.0.tar.gz`

## 3B. One-command desktop release gate

```bash
./scripts/validate-desktop-release.sh --version v0.1.0
```

From WSL, to include a native Windows export smoke:

```bash
WINDOWS_SMOKE_MODE=native ./scripts/validate-desktop-release.sh --version v0.1.0
```

This builds, smoke-tests, profiles, and packages the current desktop exports.
Validation logs and runtime JSONs land under `releases/validation/<timestamp>/`.

Runtime profiling notes:

- Linux export profiling now defaults to `PROFILE_DISPLAY_MODE=auto`.
- In displayless shells, `auto` degrades to headless profiling instead of failing on dead X11/Wayland env.
- Windows export profiling is best-effort by default in WSL/Codex shells. Set `STRICT_WINDOWS_PROFILE=1` if you want validator failure when that lane breaks.

## 4. Smoke test expectations

Windows:

- Launch `SpaceWheat.exe`
- Confirm the game starts and the native DLL is present beside the exe
- For an automated native Windows export smoke from WSL:

```bash
WINDOWS_SMOKE_MODE=native ./scripts/smoke-test-desktop-export.sh
```

- To collect runtime profile JSONs from an exported Windows bundle:

```bash
./scripts/profile-export-runtime.sh ./releases/local/windows-native
```

- To deploy that same export into the player folder:

```bash
./scripts/deploy-windows-desktop.sh
```

- To make Windows profiling failures fatal in the one-command validator:

```bash
STRICT_WINDOWS_PROFILE=1 ./scripts/validate-desktop-release.sh --version v0.1.0
```
- For a workspace-local probe that unpacks the Windows zip and runs it under Wine64:

```bash
./scripts/investigate-windows-wine.sh --mode headless
```

### Windows Godot from WSL

You can also drive a native Windows Godot binary from WSL-facing repo scripts.
Set `SW_GODOT_BIN` to the Windows executable path under `/mnt/c/...` and use the
normal profiler wrappers:

```bash
export SW_GODOT_BIN='/mnt/c/Users/Luke Spooner/Documents/antigravity_i_guess/Godot/Godot_v4.6.2-stable_win64_console.exe'
bash ./scripts/profile_headed_runtime.sh
bash ./scripts/compare_headed_renderers.sh
bash ./🍄/🧪/🧬.sh
```

The shared launcher rewrites repo-local WSL paths to Windows-visible paths, so
runtime JSON outputs land back inside the repo under `🍄/🎛️/.godot_tmp/...`.

Linux:

- Launch the exported binary through the WSL-aware launcher, or headless smoke test with writable runtime dirs:

```bash
./scripts/launch-linux-desktop.sh
```

- To capture the boot log without copying console output by hand:

```bash
./scripts/launch-linux-desktop.sh --log-file /tmp/spacewheat-linux-boot.log
./scripts/launch-linux-editor.sh --log-file /tmp/spacewheat-linux-editor.log
```

If you want to run the binary directly, use writable runtime dirs:

```bash
mkdir -p /tmp/spacewheat-runtime-home /tmp/spacewheat-runtime-config /tmp/spacewheat-runtime-data
HOME=/tmp/spacewheat-runtime-home \
XDG_CONFIG_HOME=/tmp/spacewheat-runtime-config \
XDG_DATA_HOME=/tmp/spacewheat-runtime-data \
./releases/local/linux-native/SpaceWheat.x86_64 --headless --quit-after 1
```

- To collect runtime profile JSONs from an exported Linux bundle:

```bash
./scripts/profile-export-runtime.sh ./releases/local/linux-native
```

## Notes

- Release export presets now exclude test scenes and other dev-only roots.
- Windows native shipping is supported through MinGW cross-compilation in WSL.
- The desktop workflow is now centered on `build-desktop-local.sh`, `build-web-local.sh`, `package-desktop-builds.sh`, `deploy-windows-desktop.sh`, and `validate-desktop-release.sh`.
- `./scripts/build-desktop-local.sh --copy-to-windows` refreshes the staging folder, not the player folder.
- `./scripts/deploy-windows-desktop.sh` is the only step that writes into the player-facing Windows folder.
