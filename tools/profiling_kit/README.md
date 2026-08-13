# SpaceWheat profiling kit — brief for the Windows agent

You are being asked to produce **the first trustworthy performance numbers this
game has ever had.** Not to confirm a baseline — there isn't one. Every frame
rate ever recorded for SpaceWheat was measured on a software rasteriser, because
the machine that measured them (WSL2) has no GPU passthrough. You are on the
Windows side, where the GPU is.

Everything here is self-contained and standard-library Python 3. No WSL paths,
no bash, no npm, no PowerShell 7.

---

## What is already known, and why it is worthless

| Number | Where it came from | Why it cannot stand |
|---|---|---|
| **9.5 fps** browser | `scripts/smoke-test-web-export.mjs`, 2026-08-12 | Its own report names the renderer **SwiftShader** — Chromium's software rasteriser. Headless Chromium falls back to it by default, so that lane cannot measure a GPU on any machine. |
| **10.4 fps** browser | `docs/release/WEB_DOOR.md`, 2026-07-05 | Same: SwiftShader. |
| **4.6 fps** desktop, late-game save | WSL headed, 2026-08-12 | **llvmpipe**. Also a debug build. |
| **~50 fps** desktop | `docs/performance/WSL2_GPU_SETUP.md` | The only hardware-GL number in the repo — but it predates the native-only physics cutover and the 3D renderer, records no scene and no resolution, and names a GPU this machine no longer reports. Treat as folklore. |

So: **do not compare your results to anything.** You are establishing the first
point, not confirming a trend. If a number surprises you, that is information,
not an error.

---

## The two runs

```
cd C:\Games\SpaceWheat-Releases\profiling-kit

py -3 run_desktop.py
py -3 run_web.py
```

Both write JSON into `results\` and print a summary. Both take about 10 minutes.

**Leave the game/browser window in front while a run is going.** Windows throttles
occluded windows and background browser tabs; a throttled sample reports ~1 fps
for something that is fine. Both scripts detect and flag this, but the run is
wasted either way.

### `run_desktop.py`

Launches `build\SpaceWheat.exe` — a release export carrying a perf sampler that
writes JSON and quits by itself. Six runs: three scenarios × capped/uncapped.

- `title` — the title card. The renderer's floor.
- `fresh` — a new campaign. Three biomes.
- `endgame` — a late-act save. Six biomes, the full coupling graph. **This is the
  one that decides whether a long game stays playable.**

*capped* is what a player gets (the game turns vsync on when it sees a real GPU,
so expect the refresh rate if there is any headroom at all). *uncapped* lifts
vsync and the fps ceiling so you can see how much room is actually left — 62 fps
and 400 fps both read as "60" when capped.

### `run_web.py`

Serves `web\` with the COOP/COEP headers the threaded WASM engine requires,
opens **a headed Chrome or Edge** (this is the whole point — a headless browser
would give you SwiftShader again), injects a frame counter into the page, and
collects the result. The number it reports is `requestAnimationFrame` rate:
frames the browser actually presented, which is what a player sees.

---

## What "done" looks like

Fill in `results\RESULTS.md` and leave everything in `results\`. The one thing
that must be right: **every number carries the renderer it was measured on.**
A frame rate without its renderer is an adjective, and this project has already
published two of those.

Both scripts already emit `trustworthy: true/false` plus a `caveats` list. If a
run comes back `false`, say so and say why — do not average it in, do not round
it off, do not report it as "roughly". A precise "this run cannot answer that"
is worth more than an imprecise answer.

The questions actually being asked:

1. **Does the desktop build hold a comfortable frame rate at `endgame`?** If not,
   is the cost in `process_ms` (rendering) or in `batcher.avg_batch_time_ms`
   (the physics)? Those need different fixes and the reports separate them.
2. **Does the browser build clear 20 fps on real hardware?** That is the floor in
   `docs/release/WEB_DOOR.md`, and it decides whether the itch.io page can
   truthfully say "play in the browser". Right now that line is unproven.
3. **How long does the web build take to boot?** The bundle is 193 MB, ~183 MB
   of it one resource pack. `boot_seconds` in the web report is the number that
   decides whether an asset diet comes before launch.

---

## If something does not run

- **`py -3` not found** → try `python`, or `C:\Python313\python.exe`.
- **`run_desktop.py` says "no report"** → the exe in `build\` is not the
  profiling build. Do not substitute the v1.0-rc3 pack from
  `..\v1.0-rc3\spacewheat-windows-1.0-rc3.zip`; it has no sampler in it and will
  silently produce nothing.
  *Fallback that works on any build:* `SpaceWheat.exe --print-fps` appends one
  `Project FPS: N (M mspf)` line per second to
  `%APPDATA%\Godot\app_userdata\SpaceWheat - Quantum Farm\logs\godot.log`.
  Coarser, capped, no scenario control — but it is a real number.
- **`run_web.py` finds no browser** → pass `--browser "C:\path\to\chrome.exe"`.
- **The web run says "not cross-origin isolated"** → that is a server problem,
  not a game problem, and the script serves the headers itself; report it rather
  than working around it.

## Do not

- Move the kit onto a `\\wsl$` path. 183 MB of resource pack across the 9p
  bridge looks exactly like a performance problem and is not one. `run_web.py`
  refuses outright.
- Edit anything under `build\` or `web\` — they are the artifacts under test.
- Report a number from a run whose `trustworthy` field is `false` without
  quoting the caveat next to it.
