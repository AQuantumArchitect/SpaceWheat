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
Status: first real run COMPLETE (2026-07-05) — correctness green, perf gate awaits hardware GL

- The full lane executed against a real export: build → static QA → real-Chromium
  smoke. It caught and fixed three launch bugs (`#`-comment key mangling in the
  .gdextension, missing `web.threads.wasm32` variant key, silent WASM build
  failure) — the native extension now loads in the browser
  (`gdextensionLibs: ["libquantummatrix.wasm"]`).
- Measured (this machine, SwiftShader software GL — no GPU passthrough):
  boots, `crossOriginIsolated` granted, canvas live, extension loaded, 0 fatal
  errors, main thread responsive at steady state (188ms worst ≤ 250ms budget),
  10.4 fps steady. The report now records `webgl_renderer` and the smoke
  samples after a `--settle-seconds` grace so numbers are steady-state.

Main remaining risk:
- the fps floor (≥20) cannot be judged on software GL; one run on a machine
  with hardware WebGL produces the final perf statement. Bundle weight
  (385MB) is the first diet lever if that lands near the floor.

### itch.io desktop uploads
Status: artifacts ready; publishing is an owner-seat concern, not a repo one

- Windows and Linux archives are packageable today, versioned from
  `project.godot` and stamped with the commit they were cut from.
- `scripts/itch-push.sh` is the push lane (both channels, one command). The
  earlier claim here that no such lane existed was stale.
- Account operations — installing/logging into butler, credentials, pricing,
  page approval — deliberately do NOT live in this repo. See the yurt card
  `yurt-sync/mail/for-luke-spacewheat-itch-publishing.md`. This repo's job ends
  at a finished, identifiable artifact.

### itch.io web upload
Status: correctness re-proven on the current tree — awaiting a hardware-GL perf number

- Rebuilt and re-measured 2026-08-12 against v1.0-rc3, *after* the native-only
  cutover: the bundle boots, clears the `REQUIRED_NATIVE_CLASSES` gate, and
  reports `ComplexMatrix native acceleration enabled (Eigen)` in real Chromium.
  The 2026-07-05 result was from a pre-cutover tree; this one is not.
- Still the one open number: the smoke run measures 9.5 fps, but on
  **SwiftShader** (software rasterization) — the exact case WEB_DOOR says cannot
  judge the floor. Hold the itch web channel until one hardware-GL smoke passes.

## Recommended release stance

Superseded 2026-08-13 — agree with `docs/release/ITCH_STATUS.md`:

1. Linux desktop: yes
2. Windows desktop: yes, with the native export smoke as a hard gate
3. itch.io desktop channels: yes
4. itch.io web: yes — hardware WebGL measured 59.7 fps mean (p95 19.5 ms)
   on 2026-08-12. The remaining lever is cold-start weight (~184 MiB zipped),
   not frame rate. Ship the web channel only from the same commit as desktop.

## Immediate cleanup priorities

1. Make the Windows export smoke/profile lane part of the normal release checklist.
2. Keep `scripts/build-desktop-local.sh` as the primary desktop build path.
3. Keep native build incrementality healthy so validator runs do not recompile the world for minor edits.
4. Web is release-ready on frame rate. Remaining diet: first-load weight.
