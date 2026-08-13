# How SpaceWheat's performance is measured

**One channel: `SW_PERF_LOG`.** Set it to a path and the game samples every
frame, writes a JSON report, and — with `SW_PERF_SECONDS` — quits on its own.
Unset (every player's build), the sampler disables itself on the first frame.

```bash
SW_PERF_LOG=/tmp/run.json SW_PERF_SECONDS=30 ./SpaceWheat.x86_64
```

The sampler is `Core/Debug/PerfSampler.gd`, an autoload, and it is **inside the
exported game**. That matters: `🍄/**` (the rig) and `tests/**` are excluded from
every export preset, so nothing in either can ask a shipped pack anything.

| variable | default | meaning |
|---|---|---|
| `SW_PERF_LOG` | *(unset — sampler off)* | where to write the report |
| `SW_PERF_WARMUP_SECONDS` | 15 | boot grace, sampled and reported separately |
| `SW_PERF_SECONDS` | 0 (until quit) | measurement window; quits when it elapses |
| `SW_PERF_SNAPSHOT_SECONDS` | 1 | interval for the per-second monitor snapshots |
| `SW_PERF_QUIT` | 1 | quit when the window elapses |
| `SW_UNCAP_FPS` | 0 | lift vsync and the fps ceiling — see below |
| `SW_AUTOSTART` | *(unset)* | start a campaign instead of stopping at the title |
| `SW_LOAD_PATH` | *(unset)* | load a `.tres` checkpoint into the live field |

Whole-export lane, three scenarios (title / fresh / endgame):

```bash
./scripts/profile-export-runtime.sh releases/local/linux-native
```

## Every report carries its own disqualification

An fps number without its renderer is an adjective. This project has published
two adjectives: **10.4 fps** and **9.5 fps** for the browser build, both measured
on SwiftShader, and a pile of desktop numbers measured on llvmpipe. So the report
states a verdict rather than leaving the reader to remember which box produced it:

```json
"trustworthy": false,
"caveats": [
  "adapter 'llvmpipe (LLVM 20.1.2, 256 bits)' looks like a software rasteriser — this run cannot judge an fps floor",
  "debug build — GDScript runs unoptimised and slower than the pack a player downloads"
]
```

`trustworthy` is false when the adapter looks like a software rasteriser or the
run was headless. It does **not** try to judge vsync, an fps cap, a debug build,
or too few frames — those are caveats, because they narrow what a number means
without voiding it.

Software-rasteriser detection has exactly one owner,
`PerformanceOptimizer.detect_software_renderer()`, which is also what decides the
frame cap. A second list in the sampler could drift, and then the game would cap
itself for software while the report called the run trustworthy.

## Capped and uncapped answer different questions

`PerformanceOptimizer.optimize_for_platform()` turns **vsync on** when it sees a
real GPU on the RenderingDevice backend, pins `max_fps = 60` on the OpenGL
backend (which includes the web export), and `max_fps = 30` on a software one.

So a capped run answers *"does the player get a smooth 60?"* and reports the
refresh rate whenever there is any headroom at all. `SW_UNCAP_FPS=1` answers
*"how much headroom is there?"* — 62 fps and 400 fps are indistinguishable
capped. Run both. `RuntimeEnv.describe()` is embedded verbatim in every report,
so `runtime_env.uncap_frame_rate` says which one you are holding.

## WSL cannot answer any of this

There is no GPU passthrough here: a headed run lands on llvmpipe and a headless
Chromium on SwiftShader. Real numbers come from the Windows side —
`tools/profiling_kit/`, staged onto the Windows drive by:

```bash
./scripts/stage-profiling-kit.sh
```

That builds a Windows export carrying the sampler, unpacks the web bundle beside
it, and drops in a brief. Standard-library Python 3 only: no bash, no WSL paths,
no npm, no PowerShell 7 (the Windows box has 5.1).

## What was here before

Fourteen files — four profiler scripts, seven test-runners, two Python reducers
and a GDScript harness — drove the game with `--runtime-profile-mode=…` and
friends. **Nothing has ever parsed those flags.** The one file that could
(`tests/test_headed_runtime_profile.gd`) read `PROFILE_*` environment variables
instead, was invoked by nothing, and lived under `tests/`, which every export
preset excludes. The lane launched a game, waited, found no JSON, and reported
its own missing output as a build failure — and
`scripts/validate-desktop-release.sh --profile` trusted it.

All fourteen were deleted on 2026-08-12. `tests/test_perf_lane.py` fails if any
script starts speaking to the phantom again, and pins the properties that made
the replacement reachable from a shipped build in the first place.
