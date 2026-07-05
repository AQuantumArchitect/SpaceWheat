# Itch Status

Current itch.io readiness for SpaceWheat as of 2026-04-24.

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

Status: not ready

Why:
- there is a Web preset, but not a trusted browser smoke lane
- performance for the actual live game is not yet characterized well enough
- the current web path is not the same maturity level as desktop

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
