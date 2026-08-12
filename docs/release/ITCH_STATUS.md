# Itch Status

Current itch.io readiness for SpaceWheat as of 2026-04-24.

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

**The one open number: framerate.** `smoke-test-web-export.mjs` measures 9.5 fps
against its floor of 20 — but its own report names the renderer:
`SwiftShader` (software rasterization). That is the case WEB_DOOR explicitly says
cannot judge the floor. The remaining gate is one run on hardware WebGL. Until
someone has that number, "it boots and computes correctly in a browser" is a
stronger claim than the fps line supports, and neither should be traded for the
other.

Weight is the other lever if the hardware number lands near the floor: the
bundle is ~221 MB (183 MB of it `index.pck`), which is a slow first load on a
cold cache regardless of fps.

## Practical recommendation

If you want itch soon:

1. ship Linux desktop
2. ship Windows desktop
3. do not promise the web build yet

## To make web believable

You would want at minimum:

1. one repeatable export script that produces the web bundle from current repo state
2. one browser smoke lane that verifies the exported game boots and remains responsive
3. a realistic performance profile for the real runtime, not an archived test scene
4. a clear statement about whether the web build is feature-complete or degraded
5. an explicit decision on whether web remains GDScript-only or regains a native-extension path
