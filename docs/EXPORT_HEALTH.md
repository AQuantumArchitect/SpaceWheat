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
Status: lane complete, first real run pending (2026-07-04)

- A Web preset exists in `export_presets.cfg`.
- The current web preset is now wired for native WASM GDExtension loading.
- A browser smoke lane now exists: `scripts/smoke-test-web-export.mjs`
  (Chromium via playwright-core: crossOriginIsolated, canvas attach, measured
  FPS + main-thread responsiveness, JSON verdict). Harness validated end-to-end
  against a fixture bundle; see `docs/release/WEB_DOOR.md` for the lane, the
  degradation policy (WASM-first, gallery-build fallback), and remaining gates.

Main remaining risks:
- the smoke has not yet run against a real exported bundle (needs a machine
  with Godot + web templates — three commands, documented in WEB_DOOR.md)
- no published performance numbers yet for the live game (the smoke report is
  the mechanism; the first real run produces the statement)

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
