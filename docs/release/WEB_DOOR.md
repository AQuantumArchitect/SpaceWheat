# The Web Door — lane and policy

> The Gallery, G4 (`docs/ENGINE_FRONTIER.md`, Part II). Status, **2026-08-15**:
> **every item in "What still gates the itch web channel" is checked** — the
> 2026-08-13 "complete" claim below turned out to be one day early (title
> booted, but pressing F to start a farm silently crashed; see that section
> for the fix). The bundle now boots in a real browser through the
> native-class gate, runs the C++ Eigen physics, and plays a farm: verified
> twice in real Chromium (`0af388b`, `7679b0c`) with zero console errors. On
> hardware WebGL it holds **59.7 fps mean**, six times the 20 fps floor this
> document sets. One open item remains — HEAD touched native C++ again after
> the last verified web build; see the note at the end of the checklist.
>
> This header used to say "the lane is complete" while sitting above a
> checklist with two unresolved items discovered the very next day. Read the
> checklist, not just the header.

## Why this door matters

A playable link is the portfolio's front door: no install, no trust decision,
no platform. `ITCH_STATUS.md` named the bar in April; this document is the
lane that clears it.

## The lane

| Stage | Script | What it proves |
|-------|--------|----------------|
| 1. Build | `scripts/build-web-local.sh` | Repeatable export from repo state, WASM native extension included (`variant/extensions_support=true` is already set in the preset) |
| 2. Static QA | `scripts/qa-web-export.sh` | Bundle complete; COOP/COEP headers served; loader wiring sane |
| 2.5. Wasm link check | `tests/test_web_extension_links.py` | Every symbol the extension imports is exported by something in the bundle — catches an Emscripten-version mismatch statically, no browser needed |
| 3. **Browser smoke** | `scripts/smoke-test-web-export.mjs` | The engine actually *runs* **with** isolation headers: `crossOriginIsolated` granted by a real Chromium, canvas attached, measured FPS ≥ floor, main thread responsive, no fatal console errors |
| 3.5. **Headers gate** | `scripts/gate-web-bundle.mjs` | Loads the bundle twice — with and without COOP/COEP — and asserts both the happy path (boots, farm starts) and the sad path (isolation absent) behave: a silent black screen fails the gate, a visible notice passes it |

Stage 3 emits `web-smoke-report.json` — measured FPS, worst main-thread timer
overrun, console errors, per-check verdicts. **That file is the honest
performance statement** ITCH_STATUS asked for: publish its numbers, not
adjectives.

### Running it

```bash
# on a machine with Godot 4.5 + web export templates:
./scripts/build-web-local.sh                       # 1. build (add --install-templates first time)
./scripts/qa-web-export.sh releases/web-local      # 2. static QA
python3 -m pytest tests/test_web_extension_links.py -q   # 2.5. wasm link check
npm i playwright-core                              # once
node scripts/smoke-test-web-export.mjs releases/web-local   # 3. browser smoke
node scripts/gate-web-bundle.mjs releases/web-local          # 3.5. headers gate
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

Per the degradation policy: **title/first-look can ship the full WASM-native
build.** In-farm play cannot. Headed Chrome 2026-08-14 (`PROFILE_2026-08-14.md`):
`?sw_autostart=1` reaches `BOOT SESSION STARTING` and the side module aborts
on libc++ `std::__hash_memory` (`_ZNSt3__213__hash_memoryEPKvm`). The canvas
keeps presenting at 60 fps. That is not a farm. Rebuild
`libquantummatrix.wasm` against the 4.5 template's Emscripten before calling
the pack playable.

Full write-up: `docs/performance/PROFILE_2026-08-12.md` (title) and
`docs/performance/PROFILE_2026-08-14.md` (in-farm abort).

## What still gates the itch web channel

- [x] First real smoke run (2026-07-05, this machine — see above)
- [x] Hardware-WebGL numbers (2026-08-12, Edge/D3D11 — 59.7 fps, above)
- [x] The full/gallery decision: **full**, per the policy's first clause
- [x] An honest **boot time**. Native NTFS run 2026-08-13: **20.0 s** to a live
      canvas (headed Chrome, HD 5600). The 21.4 s WSL-bridge figure was an upper
      bound by 1.4 s, not a fiction. Lever is `index.pck` 175 MiB / source
      audio 144 MB, not more GL work. See `docs/performance/PROFILE_2026-08-13.md`.
- [x] **Cross-origin isolation at the host.** Was found broken 2026-08-15: the
      alpha shipped to itch with "SharedArrayBuffer support" not ticked, so no
      COOP/COEP, so no SAB, so a threaded export never started — and the
      stock loader gave no error (a swallowed service-worker `.catch` left
      `setStatusMode()` uncalled, so the canvas stayed hidden forever).
      **Fixed in `0af388b`**: `web/spacewheat_shell.html` now ends every path
      at a visible sentence naming SharedArrayBuffer and telling an operator
      which itch checkbox to tick.
- [x] **In-farm boot.** Was found broken 2026-08-14 (title loaded, pressing F
      aborted on `undefined symbol '_ZNSt3__213__hash_memoryEPKvm'` — a
      toolchain mismatch, `libquantummatrix.wasm` built by emsdk 5.0.6 against
      a 4.0.10 template, 29 unresolved libc++ imports). **Fixed in `0af388b`**:
      `SW_EMSDK_VERSION` now hard-pins the build to 4.0.10 in
      `scripts/build-all-platforms.sh`, activation is verified rather than
      assumed, and `tests/test_web_extension_links.py` catches this class
      statically (parses the wasm import/export sections, no browser needed).
      Verified twice in real Chromium: `0af388b` (boot → farm, three full
      F/R/Q rounds, zero errors) and again in `7679b0c` after a same-day
      native edit forced a rebuild (four browser runs, zero errors).
- [x] **A no-headers browser check in the release gate.** `0af388b` added
      `scripts/gate-web-bundle.mjs`, which loads the finished bundle twice —
      with and without COOP/COEP — closing the gap `smoke-test-web-export.mjs`
      alone couldn't (it only ever served *with* headers).
- Note: the shipped bundle is **192,622,078 bytes zipped** (~184 MiB;
  `index.pck` 183 MB). Since the frame rate is no longer near the floor, a
  web-specific asset diet is a **load-time** question only.

**One open item, not a regression of the above.** HEAD (`a8986d0`, same day,
14:52) touched `native/src/multi_biome_lookahead_engine.cpp/.h` again for the
desktop async-lookahead work; its own commit message says "Web stays sync"
(the new async path is desktop-only, never called from the web GDScript
side), but the committed `native/bin/web/libquantummatrix.wasm` was not
rebuilt against that change — it's stale relative to `native/src`, just not
in a way either fix above depended on. One more `--web-only --clean` build +
`gate-web-bundle.mjs` + `smoke-test-web-export.mjs` pass against current HEAD
is the remaining action before calling this fully current — CI now runs that
build on every push touching `native/**` (see `.github/workflows/build-gdextension.yml`),
so this should stop recurring silently going forward.
