class_name PhysicsConfig

## ═══════════════════════════════════════════════════════════════════════════
## Physics / Evolution Configuration
## ═══════════════════════════════════════════════════════════════════════════
##
## TERMINOLOGY
##   phrame  — one quantum evolution step of a biome (density matrix update),
##             played at PHRAME_HZ.
##   substep — one integrator step inside a phrame (RK4 for an open biome; a
##             closed biome takes one exact U(dt) step whatever the length).
##   visual frame — one render frame (Godot _process, targeting 60fps).
##   physics tick — Godot _physics_process (PHYSICS_TICKS_HZ).
##
## THE SHARED CLOCK (owner ruling 2026-11-13)
##   Every biome, in both lanes (lookahead on and off), advances PHRAME_SIM_DT
##   of simulated time per phrame, times its observation_stride. Standing
##   contracts and gated channels tick on the same clock. One clock, so a
##   state can be found again: where a biome is in its evolution depends only
##   on how long it has run and its stride, never on which biomes it was
##   batched with or which lane ran it. Convert a wall delta with sim_dt().
##
##   A biome's max_evolution_dt is its RESOLUTION only: it caps the integrator
##   substep, it never sets how much time passes. (Before 2026-11-13 the
##   lookahead lane used it as the phrame's length too, so a biome refilling
##   alone ran at its own max_evolution_dt — Village 50× its neighbours —
##   and the rig lane ran 5× the player's clock.)
##
##   observation_stride is the speed knob: stride× sim time per phrame.
##   quantum_time_scale on BiomeBase is vestigial; nothing steps by it.
##
## COST MODEL
##   cost_per_phrame = substeps × cost_per_substep (open biomes only)
##   substeps ≈ max(1, PHRAME_SIM_DT × stride / max_evolution_dt), at most 16
## ═══════════════════════════════════════════════════════════════════════════

## Phrame rate — how many evolution calls per wall-second.
## Higher = smoother animation, more CPU cost.
## The batcher and BiomeBase both use this as their evolution interval.
const PHRAME_HZ: int = 10
const PHRAME_DT: float = 1.0 / PHRAME_HZ  # 0.1s wall-time per phrame

## Simulated time per phrame at stride 1, for every biome (the shared clock).
## 0.02 is the pace players had before the clock was shared (0.2× real time).
const PHRAME_SIM_DT: float = 0.02

## Simulated seconds per wall second at stride 1.
const SIM_RATE: float = PHRAME_SIM_DT / PHRAME_DT

## Godot physics tick rate — must match project.godot [physics] setting.
const PHYSICS_TICKS_HZ: int = 10

## Default resolution (max_evolution_dt) for a biome built without a profile.
const MAX_SUBSTEP_DT: float = 0.05


## The simulated time a wall delta is worth on the shared clock (stride 1).
static func sim_dt(wall_delta: float) -> float:
	return wall_delta * SIM_RATE
