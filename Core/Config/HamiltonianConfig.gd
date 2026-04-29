class_name HamiltonianConfig
extends RefCounted

## Canonical constants for the faction→Hamiltonian pipeline.
## Referenced by BiomeBuilder and IconBuilder — single source of truth.

## When true, each faction's H contribution is divided by its Frobenius norm
## before accumulating. Each faction casts a unit-length "rotation axis" vote
## in Hamiltonian space — more factions = richer coupling texture, not louder.
## The .jsonl profile corrections then set the actual energy scale on top.
const FACTION_DIRECTION_NORMALIZATION: bool = true

## When false, skip the biome-specific Hamiltonian JSONL patch step
## (e.g., Core/Config/Hamiltonians/starterforest.jsonl). H is then assembled
## purely from faction contributions — the target state for Phase 3.
##
## Keep true until the biome lab has swept faction-only dynamics and validated
## gameplay balance (pop yields, quest flow, rho stability on the fixed seed).
## Flipping to false without that sweep will silently detune biomes.
const APPLY_BIOME_H_PROFILE: bool = true

## Pump rate sent to FactionDensityMatrix.pump() when an Icon's owner is hit.
## Multiplied internally by DEFAULT_PUMP_SCALE = 0.01 → effective Δmass ≈ 0.001 * rate.
## Used by Farm._pump_for_icon for FDM mass injection (independent of player_affinity
## rotation, which now flows through MarketLattice.exercise_immediate).
const ICON_PUMP_OWNER_RATE: float = 10.0   # → ~0.1 mass shift per learn
const ICON_PUMP_SHARED_RATE: float = 2.0   # → ~0.02 mass shift per emoji-sharing faction

## ===========================================================================
## Phase VI universal scale (only knob in the entire system)
## ===========================================================================

## Quantum→classical resource conversion. 10 quantum units = 1 classical unit.
## Applied at the boundary between qubit measurements (which yield 1/p quantum
## units of "scarcity surprise") and the classical economy. Single dimensional
## anchor — every other "rate" in the system is graph-derived from substrate.
const QUANTUM_CLASSICAL_RATIO: float = 1.0

## Hard cap on biome qubit decoherence per atomic measurement event. Prevents
## a single contract exercise from annihilating an axis. The biome qc's drain
## function clamps eta to this; intrinsic biome dynamics (Hamiltonian + L)
## restore coherence between events.
const ETA_HARD_CAP: float = 0.5

## Minimum probability for 1/p reward clamping. At p=P_MIN, max reward =
## 1/P_MIN = 1000 quantum = 100 classical units per pop. Prevents singularity
## when a biome qubit collapses to a near-pure pole.
const P_MIN: float = 1e-3

## Overlap threshold below which a faction is excluded from settlement-θ
## distribution. Prevents micro-spreading θ across all 96 factions for
## every contract.
const PRESENCE_NOISE_FLOOR: float = 0.05

## How long an open offer remains valid (in phrames). After this, the offer
## expires and is swept by MarketLattice.expire_old. Owned contracts use the
## same window from offer time.
const CONTRACT_DEFAULT_EXPIRY_PHRAMES: int = 100

