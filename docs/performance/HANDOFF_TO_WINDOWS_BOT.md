# Performance & runtime attribution — lane handoff

**As of 2026-08-13 this lane is owned by the Windows bot.** The first hardware
pass landed the same day — `docs/performance/PROFILE_2026-08-13.md` and
`C:\Games\SpaceWheat-Releases\profiling-kit\results\RESULTS.md`. What follows
is still the orientation; the open list at the bottom is what is left.

The reason for the move is not that the WSL numbers were bad. It is that every
question left open here is a question about *a real GPU on real Windows*, and this
machine cannot answer any of them. Three separate published figures have already
been wrong because a software rasteriser or a clamped clock stood in for hardware.

---

## The one rule

**A frame rate without its renderer is an adjective.** Every number this project
published before 2026-08-12 was measured on SwiftShader (browser) or llvmpipe
(desktop), and the real hardware numbers came back **6× better**. Any report that
does not name the renderer it ran on cannot be compared to any other report.

---

## What is settled, and how far to trust it

| Claim | Status | Caveat |
|---|---|---|
| The endgame **hitches**, it does not run slow | solid | p50 ~18 ms, worst frame in seconds |
| The cause is **CPU-side, not the GPU** | solid | `draw_calls` flat at 149 through the whole run |
| Packet **lumpiness**, not total work, drove #528 | solid | per-step cost and share are flat across packet caps 1/5/21 |
| Native physics is **~11%** of headless wall time | solid | measured on a wall clock, post-fix |
| Browser build runs real Eigen physics | solid | prints the native-acceleration gate line |
| Desktop `worst frame 681 ms`, `1% low 2.1` | **floors, not values** | measured on the broken clock — see below |
| Browser `59.7 fps` | provisional | integrated HD 5600 via ANGLE, one machine |

Anything not in that table is unmeasured.

---

## The open questions — in priority order

Closed 2026-08-13 (see `PROFILE_2026-08-13.md`): #528 on real hardware (310 ms
packet → 22 ms; native 12% of wall); uncapped title/fresh (399 / 293 fps);
native web boot (20.0 s). The kit exe is now `8cb53809-dirty` and reports
`"clock": "wall"`.

1. **Where does the other ~86% of endgame wall go?** Closed. The 5 Hz
   ~90 ms train was `WitnessOrgan` (advisory decay, unread by any player
   UI). Async lookahead is live; `take` is 0.05 ms; Witness stride runs
   only when something `watch()`es. Headed endgame on the 960M holds the
   60 Hz cap (mean 60.0, p95 38.5, worst 63, 1% low 22.4). See
   `PROFILE_2026-08-16.md`. `TIME_PROCESS` is still hitch-sticky — do not
   quote `engine_process_share`. Tagged hitch logs: `VerboseConfig.hitch`.

2. **In-farm browser fps.** Query hook landed (`?sw_autostart=1&sw_perf=1`).
   Title still 59.8. Fresh/endgame **abort** at farm boot:
   `undefined symbol '_ZNSt3__213__hash_memoryEPKvm'`. Rebuild
   `libquantummatrix.wasm` against Godot 4.5's Emscripten before quoting a
   playable web number. rAF after the abort is a frozen canvas.

3. **`PACKET_TIME_BUDGET_MS = 25` cannot be met at the game's real ceiling.**
   `economy_variables.max_biome_qubits = 6`, so dim 64 is reachable in normal play —
   the shipped `endrun_ending` save already has Village at 6 qubits. One phrame there
   costs ~83 ms with the current RK4 integrator (~45 ms with the old Euler one), and
   the budget's floor is one step. The budget is therefore *advisory* at the ceiling,
   not binding. Measured per-step on this machine at the shipped save is 12.1 ms,
   so the *shipped* endgame is inside the budget; the all-6-qubit ceiling is not.

4. **Web pack diet.** 20 s cold start is real. Source audio is 144 MB of the
   175 MiB `index.pck`. Frame rate is not the lever.

### Structural lead — taken 2026-08-16

`submit_lookahead_job` is the batcher's hot path on desktop. Web stays
sync (`SPACEWHEAT_WEB_BUILD`). Packet size is worker-latency × biome
count, not uncapped Fibonacci. Do not restore 13-step packets.

---

## Traps that already cost this project time

**The clock.** `PerfSampler` used to accumulate `_process(delta)` for both its window
and its per-frame times. Godot multiplies that delta by `Engine.time_scale` and
clamps it under load, so it is not wall time. One headless run took **280.7 s and
reported 32.4 s**, and its worst frame read **884 ms when the truth was 10,384 ms**.
Medians were about right; the stalls — the thing a perf report exists to find — were
hidden by ~12×.

Fixed as of `43611ebe`: the sampler uses `Time.get_ticks_usec()` and emits
`"clock": "wall"` in its `window` block. **Check that field before comparing any two
reports.** If it is absent, the exe predates the fix and its long-frame numbers are
floors.

**A ratio is only as good as its denominator.** This project got that wrong twice in
two days on the same report — first reading `avg_batch_time_ms` (the cost of *one
packet*) as a share of the frame, then dividing real native milliseconds by a
dilated window and publishing "23% of wall" for something that is ~11%. An
impossible ratio is a gift: a synchronous main-thread call reporting 117% of its own
window is what exposed the clock bug.

**Per-packet numbers cannot compare builds.** Packet sizing is adaptive, so
ms-per-packet moves when the packet does. Use `native_ms_per_step` and `steps_total`.
At the 6-qubit ceiling the per-packet and per-step figures pointed in *opposite*
directions.

**A bigger worst frame is not automatically a regression.** Against the old numbers
it may be the first honest reading. Compare `clock` fields before comparing times.

**Don't read `packed_rho` out of a save `.tres` to learn a biome's dimension.** Those
blobs are the Witness organ's belief clusters (fixed dim 32), not biome density
matrices. The authority is a live rig read: `nb_probe` → `register_map.num_qubits`.

---

## Where the material lives

- `tools/profiling_kit/` — the kit and its brief, already written for a Windows agent
- `tools/profiling_kit/BASELINE.md` — the numbers to check against, with floors marked
- `docs/performance/PROFILE_2026-08-12.md` — the full write-up and its corrections
- `Core/Debug/PerfSampler.gd` — the sampler that ships in release builds
- `Core/Environment/BiomeEvolutionBatcher.gd` — packet sizing and the cost exports
- `tests/test_perf_lane.py` — pins the wall clock and the per-step exports

Env: `SW_PERF_LOG`, `SW_PERF_SECONDS`, `SW_PERF_WARMUP_SECONDS`,
`SW_PERF_SNAPSHOT_SECONDS`, `SW_PERF_QUIT`, `SW_AUTOSTART`, `SW_LOAD_PATH`,
`SW_MAX_PACKET_STEPS`.

---

## What a good report looks like

Name the renderer. Name the build stamp. Quote `p50` and `1% low` as a pair — the
mean describes neither state of a hitching game. If a run comes back
`trustworthy: false`, say so and say why rather than averaging it in. A precise
"this run cannot answer that" is worth more than an imprecise answer.
