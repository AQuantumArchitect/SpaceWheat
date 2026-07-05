# The Web Door — lane and policy

> The Gallery, G4 (`docs/ENGINE_FRONTIER.md`, Part II). Status, 2026-07-04:
> **the lane is complete; the first real run is pending.** This container has
> no Godot binary, so the browser smoke has been validated end-to-end against
> a fixture bundle (server spawn, COOP/COEP isolation, canvas detection, FPS
> and responsiveness sampling, JSON verdict — measured 58.8 fps on the
> fixture). The first run against a real export belongs to a machine with
> Godot 4.5 + web templates; it is three commands (below).

## Why this door matters

A playable link is the portfolio's front door: no install, no trust decision,
no platform. `ITCH_STATUS.md` named the bar in April; this document is the
lane that clears it.

## The lane

| Stage | Script | What it proves |
|-------|--------|----------------|
| 1. Build | `scripts/build-web-local.sh` | Repeatable export from repo state, WASM native extension included (`variant/extensions_support=true` is already set in the preset) |
| 2. Static QA | `scripts/qa-web-export.sh` | Bundle complete; COOP/COEP headers served; loader wiring sane |
| 3. **Browser smoke** | `scripts/smoke-test-web-export.mjs` | The engine actually *runs*: `crossOriginIsolated` granted by a real Chromium, canvas attached, measured FPS ≥ floor, main thread responsive, no fatal console errors |

Stage 3 emits `web-smoke-report.json` — measured FPS, worst main-thread timer
overrun, console errors, per-check verdicts. **That file is the honest
performance statement** ITCH_STATUS asked for: publish its numbers, not
adjectives.

### Running it

```bash
# on a machine with Godot 4.5 + web export templates:
./scripts/build-web-local.sh                       # 1. build (add --install-templates first time)
./scripts/qa-web-export.sh releases/web-local      # 2. static QA
npm i playwright-core                              # once
node scripts/smoke-test-web-export.mjs releases/web-local   # 3. browser smoke
```

Useful knobs: `--min-fps 20` (the floor), `--boot-timeout 90` (WASM
instantiation is slow on first load), `--sample-seconds 6`, `--chromium
<path>` (or `SW_CHROMIUM`) to pin a browser, `--report <path>`.

## The degradation policy (owner-blessed)

1. **WASM-native first.** The preset is already wired for the native
   extension in the browser. If the smoke passes at `--min-fps 20` on
   commodity hardware, ship the full build.
2. **The gallery build is the acceptable fallback.** If the native path
   cannot hold the floor, ship a reduced build and *say so plainly* on the
   page: fewer boot-discovered biomes, higher observation stride — the same
   physics, a smaller stage. A degraded-but-honest link beats no link.
3. **Isolation failures are hosting failures.** If `crossOriginIsolated` is
   not granted, the bundle is fine and the host is not — itch.io supports
   COOP/COEP (enable SharedArrayBuffer support in the project settings);
   self-hosting must send the two headers `serve-web-local.py` sends.

## What still gates the itch web channel

- [ ] First real smoke run (needs Godot + templates; three commands above)
- [ ] Published `web-smoke-report.json` numbers from at least one commodity
      machine — the perf statement
- [ ] The full/gallery decision made from those numbers, per the policy
- [ ] Feature-completeness statement on the itch page (full vs gallery build)
