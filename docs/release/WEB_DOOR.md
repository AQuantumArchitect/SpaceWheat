# The Web Door — lane and policy

> The Gallery, G4 (`docs/ENGINE_FRONTIER.md`, Part II). Status, **2026-08-13**:
> **the lane is complete and it has run — twice, on real exports.** See "First
> real run — 2026-07-05" and "The hardware run — 2026-08-12" below. The bundle
> boots in a real browser through the native-class gate and runs the C++ Eigen
> physics; on hardware WebGL it holds **59.7 fps mean**, six times the 20 fps
> floor this document sets.
>
> This header used to say "the first real run is pending" while sitting two
> sections above the run that happened, and it is linked from `README.md` —
> one click from the front page.

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

## First real run — 2026-07-05

The lane executed end-to-end against a real export and caught (then fixed)
three launch bugs no static check had seen:

1. **`#` is not a ConfigFile comment.** `quantum_matrix.gdextension` used `#`
   comment blocks; ConfigFile glues such lines into the next key, so the first
   entry of every block was silently mangled — the web entry (a one-line block)
   vanished entirely and the exporter packed no extension
   (`gdextensionLibs: []`). Comments are now `;`. Desktop survived only because
   the mangled `linux.x86_64`/`windows.x86_64` keys had clean `.release.`
   duplicates.
2. **Web entries must name the thread variant.** Godot 4.3+ rejects a bare
   `web.wasm32` key for thread-support exports; the entry is now
   `web.threads.wasm32` and the lib is compiled `-pthread` to match.
3. **`src/*/*.cpp` glob** in the WASM build matched nothing and em++ failed on
   the literal — silently, because the failure wasn't fatal. Now `find(1)` +
   hard exit.

**Measured verdict (this machine, honest numbers):** boots in real Chromium,
`crossOriginIsolated` granted, canvas live, native extension loaded, ZERO
fatal console errors, main thread responsive at steady state (worst overrun
188ms ≤ 250ms budget). Steady-state fps: **10.4 — on SwiftShader software
rendering** (`webgl_renderer` is now in the report; this box has no GPU
passthrough). The fps floor is the one check that cannot be judged without
hardware GL. The smoke gained `--settle-seconds` (default 10) so the sample
measures steady state, not boot churn — boot cost stays bounded by
`--boot-timeout`.

## The hardware run — 2026-08-12. The floor is cleared six times over.

Measured in **Microsoft Edge on real D3D11**, on the v1.0-rc3 bundle:

    renderer  ANGLE (Intel, Intel(R) HD Graphics 5600, Direct3D11)
    steady    59.7 fps mean · p50 16.7ms · p95 19.5ms · worst 37ms
    stall     24ms worst main-thread timer overrun
    verdict   trustworthy: true

Against a floor of 20. **The 9.5 and 10.4 fps on record were both SwiftShader
and were wrong by a factor of six** — and note the renderer above is the
*integrated* Intel chip, not the machine's GTX 960M, because browsers usually
take the iGPU on a switchable laptop. This is close to a floor for the hardware,
not a best case.

Per the degradation policy: **ship the full WASM-native build.** No gallery
fallback, no page caveat about reduced content.

Full write-up: `docs/performance/PROFILE_2026-08-12.md`.

## What still gates the itch web channel

- [x] First real smoke run (2026-07-05, this machine — see above)
- [x] Hardware-WebGL numbers (2026-08-12, Edge/D3D11 — 59.7 fps, above)
- [x] The full/gallery decision: **full**, per the policy's first clause
- [ ] An honest **boot time**. The 21.4 s recorded above was served across the
      WSL filesystem bridge and then the WSL2 localhost bridge, so it is an upper
      bound, not a measurement. A native run from
      `C:\Games\SpaceWheat-Releases\profiling-kit\` settles it.
- Note: the shipped bundle is **192,622,078 bytes zipped** (~184 MiB;
  `index.pck` 183 MB). Since the frame rate is no longer near the floor, a
  web-specific asset diet is a **load-time** question only.
