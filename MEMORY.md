# SpaceWheat Memory

Operational notes for future release/build work and other repeated tasks.

## Desktop Release Path

See [docs/release/DESKTOP_RELEASE_WORKFLOW.md](docs/release/DESKTOP_RELEASE_WORKFLOW.md) for the full build → package → validate flow (`build-desktop-local.sh`, `package-desktop-builds.sh`, `validate-desktop-release.sh`, headless smoke-test steps).

## Key Facts

- Windows native shipping is required. GDScript fallback is too slow to ship.
- Windows native DLL build is working from WSL using MinGW.
- The Windows DLL path is:
  - `native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll`
- The Linux native path is:
  - `native/bin/linux/libquantummatrix.linux.template_release.x86_64.so`

## Release Notes

- Export presets were cleaned to exclude test scenes and some dev-only roots.
- Windows export was manually launch-tested from:
  - `C:\Games\SpaceWheat Builds\windows-native\SpaceWheat.exe`
- Linux headless smoke-test steps live in docs/release/DESKTOP_RELEASE_WORKFLOW.md (writable `/tmp/spacewheat-runtime-*` dirs required).

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
