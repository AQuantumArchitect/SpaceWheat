# Itch Status

Current itch.io readiness for SpaceWheat as of **2026-08-13**.

> **Update 2026-07-11:** owner confirms the game is playable in the browser —
> the soft-launch page promises "play in the browser, or download for
> Windows + Linux" (`ITCH_PAGE.md`). The "Web channel: not ready" section
> below is superseded; a formal run of the smoke lane against the shipping
> bundle is still recommended as a release gate.

> **Update 2026-07-04:** the web channel's missing browser smoke lane now
> exists — `scripts/smoke-test-web-export.mjs` (real Chromium: isolation,
> canvas, measured FPS, responsiveness, JSON verdict), harness-validated
> against a fixture. Lane, policy, and the remaining gates are documented in
> `WEB_DOOR.md`. The five-point list below is now a lane, pending its first
> run against a real bundle on a machine with Godot + web templates.

## Desktop channels

Status: viable

- Linux desktop export is the strongest lane.
- Windows desktop export is viable and now benefits from a proven Windows runtime profiling path driven from WSL.
- The remaining work is smoke coverage and release automation polish, not fundamental build viability.

What is still missing:
- routine use of the native Windows export smoke/profile lane as a release gate

Publishing itself (butler, credentials, pricing, page approval) is not tracked
here — it belongs to the owner seat, in the yurt:
`yurt-sync/mail/for-luke-spacewheat-itch-publishing.md`. The repo's lane is
`scripts/itch-push.sh`, and it is done.

## Web channel

Status: **built and booting with native physics** (measured 2026-08-12, v1.0-rc3)

This supersedes every note above, including one written earlier the same day.

**Correction.** An earlier pass on 2026-08-12 recorded this channel as "cannot be
built on this machine — Emscripten is not installed". That was wrong, and the way
it was wrong is worth keeping: `build-all-platforms.sh` ran its `emcc`
prerequisite check *before* its own `source ~/emsdk/emsdk_env.sh`, so from a
clean shell it always reported the toolchain missing on a machine where emsdk was
fully installed. The check disagreed with the script that contained it. Hoisting
the activation above the check (one activation, not the two that had drifted
downstream) made the lane run first try.

What is now measured, not assumed:

- `native/bin/web/libquantummatrix.wasm` — **1.6 MB, built** from the Eigen
  sources by `--web-only`.
- The export carries it: `releases/web-local/libquantummatrix.wasm` sits beside
  the engine's own `index.side.wasm` (the dlink/threads template).
- In real Chromium the bundle **boots through the native-class gate** and prints
  `ComplexMatrix native acceleration enabled (Eigen)`. The C++ physics runs in
  the browser — this is not a degraded build, and there is no GDScript fallback
  for it to have quietly fallen back to.
- It carries its build stamp like any desktop pack, so a browser bug report names
  its commit.

**Framerate — answered 2026-08-12.** **59.7 fps mean, p95 19.5 ms, worst frame
37 ms**, against the 20 fps floor in `WEB_DOOR.md`. Measured on hardware WebGL
through ANGLE on an Intel HD 5600 — the *integrated* GPU, so this is near a
floor for that machine, not a best case.

This retires the 9.5 fps that stood here. That number's own report named its
renderer as `SwiftShader` (software rasterization), which `WEB_DOOR.md`
explicitly says cannot judge the floor. The real hardware figure is **six times
better**, which is the size of error a software rasteriser introduces — and the
reason every frame rate in this project must carry the renderer it was measured
on.

Weight is the remaining lever: the bundle is ~184 MiB zipped (183 MB of it
`index.pck`), which is a slow first load on a cold cache regardless of fps.

## Practical recommendation (2026-08-13)

Ship all three channels: **Linux desktop, Windows desktop, and web.**

This replaces the standing "do not promise the web build yet" that sat here
until 2026-08-13. It was written in April and never retired, so the file's
closing advice contradicted both its own supersede note above *and* the two
store copies, which promise browser play (`ITCH_PAGE.md`).

The five conditions that section set for making web believable have all been
met:

1. **Repeatable export** — `scripts/build-web-local.sh` produces the bundle
   from current repo state.
2. **Browser smoke lane** — `scripts/smoke-test-web-export.mjs`, run against a
   real export, not a fixture.
3. **Real-runtime performance** — 59.7 fps mean on hardware WebGL, p95 19.5 ms.
   Six times the 20 fps floor in `WEB_DOOR.md`.
4. **Feature-complete, not degraded** — the bundle boots through the
   native-class gate and prints `ComplexMatrix native acceleration enabled
   (Eigen)`. There is no GDScript fallback for it to have quietly taken.
5. **Native-extension path** — resolved: `web.threads.wasm32` with the lib
   compiled `-pthread`.

The one number still worth improving is **first load**: the bundle is ~184 MiB
zipped, which is a slow cold start regardless of frame rate.
