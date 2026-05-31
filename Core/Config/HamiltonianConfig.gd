class_name HamiltonianConfig
extends RefCounted

## Canonical constants for the faction→Hamiltonian pipeline.
## Referenced by BiomeBuilder and IconBuilder — single source of truth.

## Each faction's H contribution is Frobenius-normalized before accumulating,
## then the merged H is Frobenius-normalized again after Hermitianization.
## Factions vote as unit-length rotation axes; the composed H also arrives at
## the C++ solver as a unit-norm matrix regardless of how many factions fed it.
const FACTION_DIRECTION_NORMALIZATION: bool = true

## Pump rate sent to FactionDensityMatrix.pump() when an Icon's owner is hit.
## Multiplied internally by DEFAULT_PUMP_SCALE = 0.01 → effective Δmass ≈ 0.001 * rate.
## Used by Farm._pump_for_icon for FDM mass injection (independent of player_alignment
## rotation, which now flows through MarketLattice.exercise_immediate).
const ICON_PUMP_OWNER_RATE: float = 10.0   # → ~0.1 mass shift per learn
const ICON_PUMP_SHARED_RATE: float = 2.0   # → ~0.02 mass shift per emoji-sharing faction

## ===========================================================================
## Phase VI universal scale (only knob in the entire system)
## ===========================================================================

## Hard cap on biome qubit decoherence per atomic measurement event. Prevents
## a single contract exercise from annihilating an axis. The biome qc's drain
## function clamps eta to this; intrinsic biome dynamics (Hamiltonian + L)
## restore coherence between events.
const ETA_HARD_CAP: float = 0.5

## Overlap threshold below which a faction is excluded from settlement-θ
## distribution. Prevents micro-spreading θ across all 96 factions for
## every contract.
const PRESENCE_NOISE_FLOOR: float = 0.05

## How long an open offer remains valid (in phrames). After this, the offer
## expires and is swept by MarketLattice.expire_old. Owned contracts use the
## same window from offer time.
const CONTRACT_DEFAULT_EXPIRY_PHRAMES: int = 100

## Pop reward multiplier ceiling from faction affinity.
## resource_amount is scaled by (1 + AFFINITY_REWARD_MAX * affinity).
## At affinity=1.0 this doubles the base reward. Set to 0.0 to disable.
const AFFINITY_REWARD_MAX: float = 1.0

