# Baseline — what a first pass already measured, 2026-08-12

Build **v1.0-rc3 · `5a42a3f5`**, release export. Intel i7-5700HQ ×8,
NVIDIA GeForce GTX 960M (Vulkan 1.4.303), Intel HD 5600 integrated, 60 Hz,
1280×720. Every figure below comes from a report with `trustworthy: true`.

Raw JSON for these runs is **not** in `results\` — that directory is yours.
This file is the summary to check against.

## Desktop

| scenario | fps mean | p50 frame | p95 frame | worst frame | 1% low |
|---|---|---|---|---|---|
| title | 60.0 | 16.7 ms | 16.7 ms | 16.7 ms | 60.0 |
| fresh campaign (3 biomes) | 60.0 | 16.7 ms | 16.7 ms | 16.7 ms | 60.0 |
| **endgame save (6 biomes)** | **24.3** | 18.2 ms | **111.5 ms** | **681 ms** | **2.1** |

All vsync-capped at 60, so the first two are the display, not the ceiling.

**The endgame is not slow — it hitches.** Median frame 18.2 ms, worst 681 ms.
Quote the pair (p50 55 fps / 1% low 2.1 fps), never the 24.3 mean, which
describes neither state.

Cause, from the per-second snapshots:

| | value | reading |
|---|---|---|
| `draw_calls` | 149, flat | the GPU is idle |
| `physics_process_ms` | 11 ms, spiking to 400–627 ms | these spikes are the dropped frames |
| `batcher.avg_batch_time_ms` | **285–377 ms** | |
| `batcher.buffer_state` | **`RECOVERY` the entire run** | never caught up once |

The cost is the CPU-side quantum batch, not rendering. A faster GPU changes
nothing.

## Browser

Renderer: `ANGLE (Intel, Intel(R) HD Graphics 5600, Direct3D11)` — the
**integrated** GPU, not the 960M. Browsers commonly take the iGPU on a
switchable laptop, so this is near a floor for this machine.

| | value |
|---|---|
| steady-state fps | **59.7 mean** |
| p50 / p95 frame | 16.7 ms / 19.5 ms |
| worst frame | 37 ms |
| worst timer stall | 24 ms |
| settle (first 10 s) | 55.9 fps |
| boot to live canvas | 21.4 s **(upper bound — see below)** |

The floor in `docs/release/WEB_DOOR.md` is 20 fps. This clears it six times
over. The two numbers it replaces — 9.5 and 10.4 fps — were both SwiftShader.

The 21.4 s boot was served across a filesystem bridge and a network bridge.
Steady state is unaffected; boot time is not. **A native run from `web\` is the
number that counts.**
