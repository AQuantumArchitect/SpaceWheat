# How much simulated time a biome gets (2026-11-12)

A map of every parameter that sets how far a biome's ρ moves per wall second,
in both evolution lanes, and every way one biome's timing depends on another's.
Written before any fix. The numbers come from `tests/lookahead_clock_probe.gd`
(demos_normal, 30 s windows, headless, lookahead on).

## The parameters

| Parameter | Where | Value | What reads it |
|---|---|---|---|
| `PHRAME_HZ` / `PHRAME_DT` | `Core/Config/PhysicsConfig.gd` | 10 Hz / 0.1 s | The batcher plays one buffered frame per 0.1 s of physics delta (`EVOLUTION_INTERVAL`). |
| `LOOKAHEAD_DT` | `BiomeEvolutionBatcher.gd:30` | = `PHRAME_DT` | The rig lane's sim time per tick. In the lookahead lane only the fallback when a packet carries no biome. |
| `max_evolution_dt` | `BiomeBase.gd:101`, per biome | Set at build from `Core/Biomes/data/biome_characteristics.json` `max_continuous_dt`: 15 biomes 1.0, 6 10.0, 12 100.0, 2 10000.0, 7 skipped plus every biome not in the file get 0.02. The player can set it (`QuantumInstrument.set_resolution`, clamp 0.0001 to 10000). Not saved. | Six readers with two meanings; see below. |
| `observation_stride` | `BiomeBase`, per biome | 1; 0 freezes; the player's clock verb raises it (the Guide caps it at 32) | Lookahead lane: plays every stride-th frame (stride× sim time, stride× buffer burn). Rig lane: `dt × min(stride, 32)` per tick, cut into 0.1 s packets. Farm contracts: × stride. |
| `quantum_time_scale` | `BiomeBase.gd:93`, saved in GameState | 0.5 | Nothing that steps ρ. `QuantumInstrumentInput.gd:3296` calls it vestigial. `PhysicsConfig.gd` still documents `sim_dt_per_phrame = PHRAME_DT × quantum_time_scale`. |
| `MAX_SUBSTEP_DT` | `PhysicsConfig.gd:57` | 0.05 | `BiomeBase`'s default `max_evolution_dt`, overwritten at build. |
| Packet size | `FIB_SEQUENCE` `[1,1,2,3,5,8,13,21]`, per-biome index, `SW_MAX_PACKET_STEPS` | 13 to start, up to 21 | A packet's step count is the largest any biome in it asked for. |
| `dt`, `max_dt` | native `evolve(ρ, dt, max_dt)` | one value per call, for every biome in it | `dt` is sim time per output frame. A closed biome (no L) takes one exact `U(dt)ρU†` step for any dt, so `max_dt` does nothing. An open biome runs RK4: `h = 0.1·‖ρ‖/‖L(ρ)‖`, capped at `max_dt`, floored at `dt/16` (at most 16 substeps; the floor wins when `max_dt < dt/16`), then clamped to a density matrix every substep. |
| Pacing delay | `SW_PACKET_PACING_DELAY_MS` | 0 (the native default of 1 ms is overridden) | A sleep after every output frame of every biome. |
| Biome time tracker | `BiomeTimeTracker.update` | — | Lookahead lane: wall delta. Rig lane: the packet's sim dt. |
| Driven self-energies | `QuantumComputer.update_driven_self_energies` | — | No callers. Time-dependent drivers (the day/night oscillation `PhysicsConfig` describes) never reach the native H. |

### `max_evolution_dt` means two things

As **sim time per frame** (a speed):
- the lookahead packet's `dt`: the minimum over the biomes in the packet (`_get_packet_dt_for_active_flags`);
- the live-phrame `dt` from PR #65: the minimum over every running biome (`_live_phrame_dt`);
- Farm's contract tick: `delta × stride × max_evolution_dt / 0.02`, capped at 4096 (`Farm._get_lindblad_effective_delta_for_biome`);
- frame decimation when the resolution changes (`note_resolution_changed`, PR #65).

As **integrator resolution** (a substep cap):
- the rig lane's `max_dt`, with `dt = 0.1 × stride` (`BiomeDeterministicStepper`);
- `PhysicsConfig`'s cost model, the verb's name (`set_resolution`), and the continuity sweep that produced the values ("the coarsest dt that maintains continuous evolution").

Also:
- The force graph's animation scale for every biome is `(0.02 / min over all biomes)^0.25` (`QuantumForceGraph.gd:1458`). Its comment calls the smallest dt "the fastest biome".
- `GranularityController.increase/decrease_granularity` sets every biome passed to it from the first one's value.

## Measured: the lookahead lane (the player's)

| Run | Packets | Sim s per wall s |
|---|---|---|
| Idle | 14 × {StarterForest, TheDemos, Village}, 21 steps, dt 0.02 | 0.196 for all three. Village's own dt is 1.0, but the shared packet uses the minimum. |
| One write to Village at t = 0 | 15 × {Village}, dt 1.0; 14 × {StarterForest, TheDemos}, dt 0.02 | **Village 10.5** (54× its neighbours) for the rest of the window. It never rejoined the shared packet. |
| Village written every 3 s | 20 × {Village} at 1.0; 14 × the other two at 0.02 | Village about 10–14, the others 0.196 |
| TheDemos written every 3 s | 20 × {TheDemos} at 0.02; 14 × the other two at 0.02 | All about 0.2. Its own dt equals the group minimum. |

Native cost was 3–8 ms per packet. No live phrames when idle; one per write.

So in the player lane a biome's speed is set by which biomes share its refill packet. Any write splits a biome off, and the split can last indefinitely. Its speed then jumps from the group minimum to its own `max_evolution_dt`. For Village that is 50×. A biome profiled at 100 or 10000 would jump 5000× or 500000×.

## The rig lane (lookahead off, the rig's default)

Every biome advances `0.1 × stride` sim seconds per tick, so 1.0 sim s per wall s at stride 1, whoever its neighbours are. `max_evolution_dt` only caps the RK4 substep of open biomes. The memory note measured TheDemos's half-period at 10.3 s in the player lane and 2.0 s in the rig.

## How biomes touch each other

Nothing quantum couples two biomes: each has its own ρ, H and L. Everything below is scheduling.

1. **Packet dt is the minimum over the packet**, so a biome's speed depends on who it is batched with (the 54× above).
2. **Packet steps are the maximum over the packet.** Every biome gets the largest batch any of them asked for.
3. **One native job at a time.** Biomes are evolved one after another inside it, and it lands all at once. A starving biome waits for every other biome's compute. The engine refuses single-biome steps while a job runs: a written biome holds that phrame. Re-registers also wait for an empty queue.
4. **The live-phrame dt (PR #65) is the minimum over all running biomes.** This is the same coupling as 1, over every biome.
5. The 600 ms emergency-packet cooldown is global.
6. The force-graph animation scale uses the minimum `max_evolution_dt` over all biomes.
7. Mutual-information candidates are screened only at the first step of each native call. A biome's MI therefore depends on where its packets start, and that depends on its neighbours.
8. The force engine is shared natively but holds no per-call state, so it doesn't stop biomes being stepped in parallel. The unguarded runtime flags (`set_enable_mi`, `set_enable_force`, `set_pacing_delay_ms`) and Godot warnings raised inside `evolve` are the only threading hazards.

## Other loose ends found on the way

- Farm contracts tick on wall delta × `max_evolution_dt / 0.02`, not on the evolution clock. In the player lane a 0.02 biome's contract runs 5× faster than its H (0.1 vs 0.02 sim s per tick); in the rig lane the two are equal. Village's contracts run 50×.
- A lone open biome at dt 100 runs 16 RK4 substeps with h ≥ 6.25, far outside RK4's stability region. The density-matrix clamp keeps ρ bounded but wrong. Closed biomes are exact at any dt.
- The native comments still describe "adaptive Euler with a purity constraint"; the code is RK4 with a relative-change step.
- `LindbladBuilder.build_from_atoms` builds L when the world is open even for a biome whose regime is `"closed"` (it ORs the world switch with `force_open`). The enclave stays dissipative after the door.

## Decisions this needs

1. Does `max_evolution_dt` mean resolution only, with every biome sharing one clock and stride as the only speed knob? Or is it also each biome's own speed?
2. If there is one clock, how many sim seconds per frame: 0.02 (players today), 0.1 (rig today) or 0.05 (`PhysicsConfig`'s documented 0.5×)?
3. Should Farm's contract tick follow that same clock?

A per-biome substep inside one native call, and stepping biomes on parallel threads, need a C++ change to `MultiBiomeLookaheadEngine` and rebuilt binaries. That is its own PR, after these decisions.

## Outcome (2026-11-13)

Owner ruling: one shared clock, "because we want to find particular states". The clock is 0.02 sim-s per phrame, the pace players already had. Standing contracts follow the same clock. `max_evolution_dt` is resolution only. Branch `shared-clock`, stacked on PR #65:

- Every native call runs `PHRAME_SIM_DT` per frame. The substep cap is the biome's own `max_evolution_dt` for single-biome calls, and the packet's finest for batched ones; a per-biome cap inside one call needs the native PR.
- The rig lane converts wall time with `PhysicsConfig.sim_dt`, so it slows 5× to match players.
- Farm's channels tick `sim_dt × stride` (capped at 32), with no resolution factor.
- The force graph's wobble no longer scales with resolution. Frame decimation on a resolution change is gone; the change now re-forecasts.
- Found while measuring: a refill was seeded from the live ρ but appended after the frames still waiting, so the player lane replayed 2 frames per 21-frame refill (TheDemos period 221 vs 196 ticks). Refills now seed from the buffer's last frame. Packets replacing frozen placeholders skip the ticks those placeholders stood in for. Measured after the fix: 198 vs 196 ticks, with no backward steps.
- Still open: the biome time tracker is a wall-clock counter that up to three code paths advance. In the lookahead lane a stride above the buffer depth is capped by the buffer; not measured.
