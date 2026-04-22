class_name HamiltonianConfig
extends RefCounted

## Canonical constants for the faction→Hamiltonian pipeline.
## Referenced by BiomeBuilder and IconBuilder — single source of truth.

## When true, each faction's H contribution is divided by its Frobenius norm
## before accumulating. Each faction casts a unit-length "rotation axis" vote
## in Hamiltonian space — more factions = richer coupling texture, not louder.
## The .jsonl profile corrections then set the actual energy scale on top.
const FACTION_DIRECTION_NORMALIZATION: bool = true

## When false, ALL factions contribute at full strength (1.0) regardless of
## any standings dict. Set true to enable Phase 2 reputation weighting.
const FACTION_STANDINGS_ENABLED: bool = false
