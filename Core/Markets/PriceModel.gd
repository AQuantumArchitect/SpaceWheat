class_name PriceModel
extends RefCounted

## PriceModel — substrate-derived contract pricing, no magic numbers.
##
## The price IS the faction's risk-neutral valuation of its own observable on
## the contract qubit. Concretely:
##
##   1. Compose the biased ρ_market via MarketBiasSources (biome supply, world
##      mass, realized-biome resonance, player-faction resonance, standings).
##   2. Read P(gozouta) — the probability the faction's preferred pole pays out.
##   3. price = −kT·log P(gozouta) — the Boltzmann surprisal energy of the
##      payout (EnergyPricing), = the information the faction must pay to realize
##      it. kT is the biome's market temperature (warmer = steeper, mixed biomes).
##   4. Apply standing modifier: high legitimacy discounts, debt premiums.
##
## Properties (at kT≈10):
##   - At P=0.5 (neutral): price ≈ 6.9 classical (the fair middle).
##   - At P=0.99 (near-certain): price ≈ 0.1 classical (cheap, no surprise).
##   - At P=0.01 (rare lottery): price ≈ 46 classical — bounded, no 1/p cliff.
##   - Determinism: same substrate state → same price, no RNG.



static func price_contract(contract, farm) -> float:
	if contract == null:
		return 0.0
	# Null farm is valid (degraded substrate); all sources return 0 → neutral price.
	var rho: Dictionary = MarketBiasSources.compose_market_qubit(contract, farm)
	var p_gozouta: float = float(rho.get("p_gozouta", 0.5))
	# Boltzmann scarcity: price = surprisal energy E = −kT·log p (EnergyPricing).
	# The faction's risk-neutral valuation of its own observable on the qubit.
	var biome = MarketBiasSources._safe_get_biome(contract, farm)
	var kT: float = EnergyPricing.biome_temperature(biome, farm)
	var price_classical: float = EnergyPricing.surprisal_energy(p_gozouta, kT)

	price_classical *= standing_factor(contract.faction, farm)

	return price_classical


static func standing_factor(faction_name: String, farm) -> float:
	# Standing modifier: legitimacy discounts (factor < 1), debt premiums
	# (factor > 1); 1.0 at neutral. atan()/(PI/2) soft-clips to (0.5, 1.5) so
	# extreme standings don't blow up the price. Shared by contract pricing
	# and the Merchant order-book card.
	var legitimacy: float = 0.0
	var debt: float = 0.0
	if farm != null and faction_name != "" and "faction_standings" in farm and farm.faction_standings != null:
		var s = farm.faction_standings.get(faction_name, null)
		if s != null:
			legitimacy = float(s.legitimacy)
			debt = float(s.debt)
	var net_standing: float = legitimacy - debt
	return clampf(1.0 - 0.5 * (atan(net_standing) / (PI * 0.5)), 0.1, 10.0)


static func implied_marginal(contract, farm) -> float:
	# For UI / pricing displays: just the gozouta marginal under the bias-composed ρ.
	if contract == null:
		return 0.5
	var rho: Dictionary = MarketBiasSources.compose_market_qubit(contract, farm)
	return float(rho.get("p_gozouta", 0.5))
