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
- first-class `butler push` automation
- routine use of the new native Windows export smoke/profile lane as a release gate

## Web channel

Status: **cannot be built on this machine** (measured 2026-08-12, v1.0-rc3)

This supersedes both notes above. The 2026-07-11 update said the owner had
confirmed browser play; that was true of a bundle built *before* the native-only
cutover. It is no longer reachable, and the blocker is mechanical, not a
judgement call:

- `native/bin/web/` is **empty** — the WASM extension has never been built here.
- **Emscripten is not installed.** `build-all-platforms.sh --web-only` shells out
  to `em++` to produce `bin/web/libquantummatrix.wasm`; the lane exists and is
  wired, the toolchain is simply absent.
- Since the native-only purge, `BootManager._ready()` **hard-fails** — it calls
  `get_tree().quit(1)` when `REQUIRED_NATIVE_CLASSES` are missing. A web build
  without that WASM does not degrade to GDScript physics; it refuses to start.
  There is no fallback left to fall back to.
- `releases/web-local/` is from 2026-07-05, which predates that cutover.
  **Do not ship it.**

Order to make web real: install emsdk → `build-all-platforms.sh --web-only` →
export the Web preset → run `scripts/smoke-test-web-export.mjs` against the real
bundle (the lane exists and has never been run against one).

**Page-copy conflict, unresolved:** `ITCH_PAGE.md` promises "Play-in-browser +
desktop downloads" and the title section repeats it. Until the above is done,
either cut the browser promise from the page or hold the page. Shipping the copy
as written promises something that currently cannot boot.

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
