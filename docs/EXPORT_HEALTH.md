# Export Health

Current export health for SpaceWheat as of 2026-04-24.

## Summary

### Linux desktop
Status: healthy

- `scripts/build-desktop-local.sh` builds Linux desktop exports.
- `scripts/smoke-test-desktop-export.sh` actually boots the exported Linux binary headless.
- Native C++ packaging is present and checked.

Main remaining risk:
- target-machine graphics/runtime performance, not packaging correctness

### Windows desktop
Status: mostly healthy

- `scripts/build-desktop-local.sh` builds Windows desktop exports with the native DLL.
- Packaging via `scripts/package-desktop-builds.sh` is in place.
- `scripts/smoke-test-desktop-export.sh` now has a native Windows export smoke mode via `WINDOWS_SMOKE_MODE=native`.
- `scripts/profile-export-runtime.sh` now profiles exported Windows bundles, not just project/editor runtime.
- Real Windows runtime profiling now works from WSL via `SW_GODOT_BIN`.
- The Windows-side collaborator confirmed:
  - headed profiler works
  - renderer comparison works
  - biome stress workloads work
  - Fibonacci ladder workloads work
  - JSON outputs round-trip back into the repo correctly

Main remaining risk:
- the native Windows export smoke/profile lane now exists, but it still needs routine use as a release gate
- exported Windows profiling from sandboxed WSL/Codex shells is still unreliable, so that lane is currently best validated from a real Windows-side process

### Web export
Status: experimental

- A Web preset exists in `export_presets.cfg`.
- The repo does not currently have a trusted automated browser/runtime smoke lane for the live game.
- The current web preset is now wired for native WASM GDExtension loading.

Main remaining risks:
- no modern browser verification loop
- no current performance confidence for the live game
- stale docs overstate readiness

### itch.io desktop uploads
Status: close, but manual

- Windows and Linux archives are packageable today.
- The repo does not yet have a first-class `butler push` lane.
- Desktop itch distribution is realistic once release packaging/versioning is finalized.

### itch.io web upload
Status: not production-ready

- The preset exists, but the runtime validation story is not strong enough.
- Treat HTML5/itch web export as exploratory only.

## Recommended release stance

If you had to choose today:

1. Linux desktop: yes
2. Windows desktop: yes, with continued smoke tightening
3. itch.io desktop channels: yes
4. itch.io web: no, not yet

## Immediate cleanup priorities

1. Make the Windows export smoke/profile lane part of the normal release checklist.
2. Keep `scripts/build-desktop-local.sh` as the primary desktop build path.
3. Keep native build incrementality healthy so validator runs do not recompile the world for minor edits.
4. Do not describe Web as release-ready until it has:
   - a browser/runtime smoke path
   - a believable performance envelope for the current game
