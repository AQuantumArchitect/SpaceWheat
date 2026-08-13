# SpaceWheat profiling kit — brief for the Windows agent

A first pass has already been taken — see **`results\BASELINE.md`** for what it
found and `docs/performance/PROFILE_2026-08-12.md` in the repo for the full
write-up. Your job is to **confirm it natively and close the three gaps it
names.** A second independent measurement of a number that decides a release is
worth having; so is a boot time that isn't distorted by a filesystem bridge.

Everything here is self-contained and standard-library Python 3. No WSL paths,
no bash, no npm, no PowerShell 7.

---

## What is already measured (2026-08-12, trustworthy)

Build v1.0-rc3 · `5a42a3f5`, release export, GTX 960M / Intel HD 5600, 60 Hz.

| | result |
|---|---|
| desktop, title | 60.0 fps, not one dropped frame |
| desktop, fresh campaign | 60.0 fps, not one dropped frame |
| **desktop, endgame save** | p50 **55 fps**, 1% low **2.1 fps**, worst frame **681 ms** |
| **browser** | **59.7 fps** mean, p95 19.5 ms — clears the 20 fps floor six times over |

The endgame result is a **hitch**, not a slowdown. `draw_calls` stays flat at 149, so
the GPU is idle and the cost is CPU-side. The specific cause: the quantum batch was
computed in one synchronous ~310 ms lump per packet, so the rare frame that caught a
packet stalled for a third of a second while every other frame was fine.

**That is fixed as of 2026-08-13** — packet size is now bounded by a measured time
budget (310 ms → 27 ms per packet, same total work). **The desktop table above was
measured BEFORE the fix.** Your run measures the fixed build, so the endgame's worst
frame and 1% low should be much better. Report what you actually see either way.

One caution the first pass got wrong: `avg_batch_time_ms` is the cost of *one packet*,
not a share of the frame. To get the share, use the cumulative `native_ms_total` /
`packets_total` fields now in the report. Measured honestly, the native call is ~23%
of wall time, not all of it.

## What every earlier number was worth: nothing

| Number | Why it cannot stand |
|---|---|
| 9.5 fps browser | its own report names the renderer **SwiftShader** |
| 10.4 fps browser | same |
| 4.6 fps desktop | **llvmpipe**, and a debug build |
| ~50 fps desktop (`WSL2_GPU_SETUP.md`) | predates the physics cutover and the 3D renderer; no scene, no resolution, a GPU this machine no longer reports |

The browser build is **six times faster** than the number that was on record for
it this morning. That is the size of error a software rasteriser introduces —
which is why the rule below is the one rule that matters.

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
published two of those and been wrong by 6×.

Both scripts emit `trustworthy: true/false` plus a `caveats` list. If a run comes
back `false`, say so and say why — do not average it in, do not round it off, do
not report it as "roughly". A precise "this run cannot answer that" is worth more
than an imprecise answer.

### The three gaps

1. **A native web boot time.** The 21.4 s already recorded is an upper bound: the
   bundle was served across the WSL filesystem bridge and then the WSL2 localhost
   bridge. Running from `web\` on this machine removes both. That number decides
   whether the 183 MB resource pack gets a diet before launch.
2. **The uncapped desktop pass.** Everything measured so far is vsync-capped at
   60, so the headroom on `title` and `fresh` is unknown — 62 fps and 400 fps
   look identical. `run_desktop.py` runs capped and uncapped by default.
3. **Confirm or refute the endgame hitch.** Does `endgame` reproduce the 681 ms
   worst frame and the permanent `RECOVERY` state? If yes, the CPU-side batcher
   diagnosis stands and it is a real bug. If your run looks different, say so
   loudly — a finding that does not reproduce is more useful than one that is
   politely agreed with.

Anything else you notice is welcome. A stutter the JSON does not capture, a
scenario that behaved unlike its numbers, a run that failed strangely — write it
down as what it did, not as what you think it meant.

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
