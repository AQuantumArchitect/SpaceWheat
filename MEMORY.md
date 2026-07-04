# SpaceWheat Memory

Operational notes for future release/build work and other repeated tasks.

## Desktop Release Path

Use the local desktop release flow from the current checkout:

```bash
./scripts/build-desktop-local.sh --install-templates
```

This builds:

- `releases/local/windows-native/SpaceWheat.exe`
- `releases/local/linux-native/SpaceWheat.x86_64`

To also stage the builds onto the Windows filesystem:

```bash
./scripts/build-desktop-local.sh --copy-to-windows
```

Default Windows staging folder:

- `C:\Games\SpaceWheat Builds\windows-native`
- `C:\Games\SpaceWheat Builds\linux-native`

## Packaging

Package the exported folders with:

```bash
./scripts/package-desktop-builds.sh --version v0.1.0
```

Outputs:

- `releases/packages/spacewheat-windows-v0.1.0.zip`
- `releases/packages/spacewheat-linux-v0.1.0.tar.gz`

## Key Facts

- Windows native shipping is required. GDScript fallback is too slow to ship.
- Windows native DLL build is working from WSL using MinGW.
- The Windows DLL path is:
  - `native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll`
- The Linux native path is:
  - `native/bin/linux/libquantummatrix.linux.template_release.x86_64.so`
- Export templates can be installed with:

```bash
./scripts/install-godot-export-templates.sh
```

## Release Notes

- Export presets were cleaned to exclude test scenes and some dev-only roots.
- Windows export was manually launch-tested from:
  - `C:\Games\SpaceWheat Builds\windows-native\SpaceWheat.exe`
- Linux exported binary headless smoke-test works when given writable runtime dirs:

```bash
mkdir -p /tmp/spacewheat-runtime-home /tmp/spacewheat-runtime-config /tmp/spacewheat-runtime-data
HOME=/tmp/spacewheat-runtime-home \
XDG_CONFIG_HOME=/tmp/spacewheat-runtime-config \
XDG_DATA_HOME=/tmp/spacewheat-runtime-data \
./releases/local/linux-native/SpaceWheat.x86_64 --headless --quit-after 1
```

## Runtime Authority

- The live UI/runtime discovery graph is now centered on `Core/Instrumentation/InstrumentLocator.gd`.
- Prefer `InstrumentLocator` over direct `"/root/..."` scavenging in runtime code.
- The remaining direct `"/root/..."` lookups should be treated as either locator internals or intentional compatibility/debug surfaces.
- The old `FarmUIState` / `GameController` / `SaveDataAdapter` / `ActionDispatcher` / `ProbeHandler` runtime tests were removed from the active test set; if they matter again, they belong in archived history, not the live suite.

## Canonical Doc

For the fuller workflow, see:

- [docs/release/DESKTOP_RELEASE_WORKFLOW.md](docs/release/DESKTOP_RELEASE_WORKFLOW.md)

## `🍄` Folder Map

`🍄` is the LLM automation and experiment lane, not core runtime game code. Future instances should treat it as a separate ops surface with a few real entrypoints and a lot of generated or historical support material.

Read these first:

- [`🍄/README.txt`](🍄/README.txt)
  - top-level purpose, quick-start commands, artifact policy
- [`🍄/🎛️/📘.md`](🍄/🎛️/📘.md)
  - canonical live-rig / QA operator guide
- [`🍄/🎛️/🧠🗺️.md`](🍄/🎛️/🧠🗺️.md)
  - rig intent, action surface, and planned extensions
- [`🍄/🧪/README_🧬.md`](🍄/🧪/README_🧬.md)
  - focused biome stress-test wrapper and what it validates
- [`🍄/artifacts_whitelist/README.txt`](🍄/artifacts_whitelist/README.txt)
  - only place under `🍄` where committed runtime artifacts belong

Practical structure:

- `🍄/🎛️`
  - live rig, milk-hunt runners, orchestrators, config, logs
  - main operator entrypoints are `🟢.sh`, `✍️.sh`, and `🥛🏃.sh`
- `🍄/🧪`
  - targeted shell wrappers for stress and validation passes
  - not the same thing as the repo-wide `Tests/` tree; mostly convenience runners
- `🍄/🛠️`
  - utility scripts and support tooling
- `🍄/artifacts_whitelist`
  - curated, commit-safe output samples only

Interpretation notes:

- Most root-level `🍄/EMOJI_*`, `emoji_*.txt`, and manifest files are vocabulary/palette/reference material, not day-to-day operator docs.
- `🍄/🎛️/config/` is the main source of truth for rig-side configs, world states, starter resources, characters, and emoji support assets.
- If the task is “run the game through the rig” or “investigate automation lanes,” start in `🍄/README.txt` and `🍄/🎛️/📘.md`, not by scanning scripts blindly.
- Artifact hygiene matters: bulk logs and runtime outputs under `🍄` are intentionally ignored; do not version them outside `🍄/artifacts_whitelist/`.
