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
./scripts/package-desktop-builds.sh
```

This produces:

- `releases/packages/spacewheat-windows-<version>.zip`
- `releases/packages/spacewheat-linux-<version>.tar.gz`

The `<version>` is not typed: `package-desktop-builds.sh` greps
`config/version` out of `project.godot`, so the archive name and the
title-screen stamp cannot drift apart. Passing `--version` overrides that
and reintroduces exactly the drift the default exists to prevent — don't,
unless you are deliberately renaming a build.

## 3B. One-command desktop release gate

```bash
./scripts/validate-desktop-release.sh
```

From WSL, to include a native Windows export smoke:

```bash
WINDOWS_SMOKE_MODE=native ./scripts/validate-desktop-release.sh
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
STRICT_WINDOWS_PROFILE=1 ./scripts/validate-desktop-release.sh
```
- For a workspace-local probe that unpacks the Windows zip and runs it under Wine64:

```bash
./scripts/investigate-windows-wine.sh --mode headless
```

### Windows Godot from WSL

You can also drive a native Windows Godot binary from WSL-facing repo scripts.
Set `SW_GODOT_BIN` to the Windows executable path under `/mnt/c/...`; the shared
launcher rewrites repo-local WSL paths to Windows-visible paths.

```bash
export SW_GODOT_BIN='/mnt/c/Users/Luke Spooner/Documents/antigravity_i_guess/Godot/Godot_v4.6.2-stable_win64_console.exe'
```

**Note on performance numbers from WSL: don't.** WSL has no GPU passthrough
here, so a headed run lands on llvmpipe and any fps it reports is a software
rasteriser's, not the machine's. Profiling is a Windows-side job — see
`docs/performance/PROFILING.md`.

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

---

## Pre-release checklist

Moved here 2026-08-13 from `docs/release/RELEASE_README.md`, which was deleted:
that file was last touched 2026-07-05, was linked from nothing, and had gone
wrong about the version, the tarball name, the extraction step, the binary size,
and macOS support. This checklist was the one part worth keeping.

Before any itch.io push (`scripts/itch-push.sh`):

1. Linux export builds and boots (`scripts/build-linux-release.sh`).
2. **Windows export smoke passes** — boot to the title screen and one
   measure/harvest cycle on the packaged Windows build. A build that boots on
   the packager's GPU is not a build that boots everywhere; this gate exists
   because the Windows lane otherwise only runs when someone remembers.
3. Headless assays green:
   `python3 tools/plant_assay.py && python3 tools/channel_assay.py`.
4. Web channel only after `scripts/smoke-test-web-export.mjs` has passed against
   a real exported bundle (see `WEB_DOOR.md`) — otherwise desktop-only.
5. **`LICENSE` and `THIRD_PARTY_NOTICES.md` are inside every archive.**
   `package-desktop-builds.sh` copies them and refuses to build without them.
   Twemoji is CC-BY 4.0 and attribution is its only condition; every archive
   shipped before 2026-08-13 carried binaries only and did not meet it.
