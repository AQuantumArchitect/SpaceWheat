class_name PhysicsConfig

## ═══════════════════════════════════════════════════════════════════════════
## Physics / Evolution Configuration
## ═══════════════════════════════════════════════════════════════════════════
##
## TERMINOLOGY
##   phrame  — one quantum evolution call (density matrix update).
##   substep — one Euler integration step inside a phrame.
##   visual frame — one render frame (Godot _process, targeting 60fps).
##   physics tick — Godot _physics_process (PHYSICS_TICKS_HZ).
##
## HOW THE DAY/NIGHT CYCLE WORKS
##   The day/night cycle is driven by a cosine oscillator on the ☀/🌙 axis.
##   Its period in wall-clock time depends on three things:
##
##   1. Driver frequency (f)   — set per-biome in Hamiltonians/*.jsonl
##      e.g. StarterForest ☀ driver: f = 0.04 Hz → T_sim = 25s
##
##   2. Sim-speed (quantum_time_scale on BiomeBase)
##      sim-seconds advanced per wall-second. Default 0.5.
##      T_wall = T_sim / quantum_time_scale = 25 / 0.5 = 50s
##
##   3. Phrame rate (PHRAME_HZ)
##      How often we call evolve() per wall-second. Does NOT affect cycle
##      length — only affects how smooth the animation looks between frames.
##
##   To change cycle length, change the driver frequency or quantum_time_scale.
##   To change smoothness, change PHRAME_HZ.
##
## COST MODEL
##   cost_per_phrame = substeps × cost_per_substep
##   substeps = ceil(sim_dt_per_phrame / MAX_SUBSTEP_DT)
##   sim_dt_per_phrame = (1/PHRAME_HZ) × quantum_time_scale
##
##   Example (StarterForest defaults):
##     sim_dt_per_phrame = (1/10) × 0.5 = 0.05s
##     substeps = ceil(0.05 / 0.05) = 1
##     cost ≈ 27ms × 1 = 27ms per phrame (with Eigen backend)
##     Budget at 10Hz = 100ms → 73ms headroom for rendering + force graph
## ═══════════════════════════════════════════════════════════════════════════

## Phrame rate — how many evolution calls per wall-second.
## Higher = smoother animation, more CPU cost.
## The batcher and BiomeBase both use this as their evolution interval.
const PHRAME_HZ: int = 10
const PHRAME_DT: float = 1.0 / PHRAME_HZ  # 0.1s wall-time per phrame

## Godot physics tick rate — must match project.godot [physics] setting.
const PHYSICS_TICKS_HZ: int = 10

## Upper bound on sim-time per Euler substep.
## Controls numerical accuracy vs cost tradeoff.
## At 0.05, a typical phrame (sim_dt ≈ 0.05) is ONE substep.
## Halving this doubles the number of substeps (and cost).
## Safe range for StarterForest coupling strengths (||H|| ≈ 2-3): up to 0.1.
const MAX_SUBSTEP_DT: float = 0.05
