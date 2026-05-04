class_name PriceModel
extends RefCounted

## PriceModel — substrate-derived contract pricing, no magic numbers.
##
## The price IS the faction's risk-neutral valuation of its own observable on
## the contract qubit. Concretely:
##
##   1. Compose the biased ρ_market via MarketBiasSources (biome supply, world
##      mass, faction-biome resonance, player-faction resonance, standings).
##   2. Read P(gozouta) — the probability the faction's preferred pole pays out.
##   3. price_quantum = 1/P(gozouta) — the natural information weight (= what
##      the faction expects to lose at exercise under its own lens).
##   4. Multiply by QUANTUM_CLASSICAL_RATIO to get classical units.
##   5. Apply standing modifier: high legitimacy discounts, debt premiums.
##
## Properties:
##   - At P=0.5 (neutral): price = 2 × QC_RATIO = 20 classical (the fair middle).
##   - At P=0.99 (faction sees gozouta as near-certain): price ≈ 10 classical.
##   - At P=0.01 (rare lottery): price = 1000 classical.
##   - Determinism: same substrate state → same price, no RNG.

const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
const MarketBiasSources = preload("res://Core/Markets/MarketBiasSources.gd")


static func price_contract(contract, farm) -> float:
	if contract == null:
		return 0.0
	# Null farm is valid (degraded substrate); all sources return 0 → neutral price.
	var rho: Dictionary = MarketBiasSources.compose_market_qubit(contract, farm)
	var p_gozouta: float = float(rho.get("p_gozouta", 0.5))
	var p_clipped: float = clampf(p_gozouta, HamiltonianConfig.P_MIN, 1.0 - HamiltonianConfig.P_MIN)
	var price_quantum: float = 1.0 / p_clipped
	var price_classical: float = price_quantum * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO

	# Standing modifier: legitimacy discounts (factor < 1), debt premiums (factor > 1).
	# Use a soft-clip so extreme standings don't blow up the price.
	var legitimacy: float = 0.0
	var debt: float = 0.0
	if farm != null and "faction_standings" in farm and farm.faction_standings != null:
		var s = farm.faction_standings.get(contract.faction, null)
		if s != null:
			legitimacy = float(s.legitimacy)
			debt = float(s.debt)
	# Standing factor: 1.0 at neutral, < 1 with high legitimacy, > 1 with debt.
	# atan() / (PI/2) maps to (-1, 1); range factor (0.5, 1.5).
	var net_standing: float = legitimacy - debt
	var standing_factor: float = 1.0 - 0.5 * (atan(net_standing) / (PI * 0.5))
	price_classical *= clampf(standing_factor, 0.1, 10.0)

	return price_classical


static func implied_marginal(contract, farm) -> float:
	# For UI / pricing displays: just the gozouta marginal under the bias-composed ρ.
	if contract == null:
		return 0.5
	var rho: Dictionary = MarketBiasSources.compose_market_qubit(contract, farm)
	return float(rho.get("p_gozouta", 0.5))
