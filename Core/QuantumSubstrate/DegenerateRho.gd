class_name DegenerateRho
extends RefCounted

## DegenerateRho — the one place that decides whether a packed density matrix is
## too degenerate to hand to the native engine, and what a clean replacement is.
##
## A ρ whose trace has collapsed to zero (or gone NaN) is not a state. Feeding one
## to the C++ evolution engine SIGABRTs — Eigen's decompositions have no defined
## answer for it — so every site that ships a packed ρ across the native boundary
## has to check first. Three sites grew that check independently:
##
##   • Core/Environment/BiomeDeterministicStepper.gd  (time-skip cycle)
##   • Core/Environment/BiomeEvolutionBatcher.gd      (per-biome status gather)
##   • Core/Environment/BiomeEvolutionBatcher.gd      (packet queue, active flags)
##
## All three agreed on the epsilon (1e-10). They did NOT agree on NaN: only the
## status-gather site tested `is_nan(trace)`. That gap is not cosmetic — a NaN
## trace fails `trace < 1e-10` (every comparison against NaN is false), so the
## other two sites waved NaN straight through to the exact crash the guard exists
## to prevent. Unifying here closes that hole rather than preserving it in
## triplicate.
##
## What the three sites legitimately differ on is the REMEDY: two rebuild the
## biome as a maximally mixed state and carry on, one marks the biome inactive
## for that packet. That's policy, and it stays with the caller. Detection and
## the replacement state are physics, and they live here.

## Trace collapse threshold. Below this a density matrix carries no probability
## at all and every normalized observable derived from it is a division by ~zero.
const TRACE_EPSILON := 1e-10


## Sum the real diagonal of a row-major packed ρ ([re00, im00, re01, im01, ...]).
## Returns NAN when the buffer is too small to hold a dim×dim matrix — an
## undersized ρ is not a zero-trace ρ, and callers must not confuse the two.
static func packed_trace(rho_packed: PackedFloat64Array, dim: int) -> float:
	if dim <= 0 or rho_packed.size() < dim * dim * 2:
		return NAN
	var trace := 0.0
	for i in range(dim):
		# Element (i, i) starts at ((i * dim) + i) * 2 == i * (dim + 1) * 2.
		trace += rho_packed[i * (dim + 1) * 2]
	return trace


## Is this trace unusable as a density-matrix normalization?
## NaN counts. It has to: NaN < eps is false, so a bare threshold test reads a
## NaN trace as perfectly healthy.
static func is_degenerate_trace(trace: float) -> bool:
	return is_nan(trace) or trace < TRACE_EPSILON


## Convenience: trace the packed ρ and judge it in one call.
static func is_degenerate(rho_packed: PackedFloat64Array, dim: int) -> bool:
	return is_degenerate_trace(packed_trace(rho_packed, dim))


## The maximally mixed state I/dim, packed. This is the honest replacement for a
## collapsed ρ: it asserts nothing about the biome beyond "dim outcomes, no
## information", which is exactly what a zero-trace matrix has left to say.
static func maximally_mixed_packed(dim: int) -> PackedFloat64Array:
	var fresh := PackedFloat64Array()
	if dim <= 0:
		return fresh
	fresh.resize(dim * dim * 2)
	var diag_val := 1.0 / float(dim)
	for i in range(dim):
		fresh[i * (dim + 1) * 2] = diag_val
	return fresh
