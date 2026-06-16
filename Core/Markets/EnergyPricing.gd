class_name EnergyPricing
extends RefCounted

## Boltzmann/Gibbs scarcity: E = −kT·log p. Energy is negative log-probability
## up to scale. The single scarcity law behind every reward, price, and cost
## in the economy.
##
## Why this replaces the legacy 1/p kernel:
##   - It IS energy. p = e^(−E/kT)/Z ⟺ E = −kT·log p − kT·log Z; the log Z
##     baseline cancels in any price *difference*. "Price = energy to realize
##     this good" becomes the definition, not a metaphor.
##   - Bundles add: −kT·log(p_a·p_b) = E_a + E_b. The log turns a basket's
##     multiplicative joint probability into additive prices for free.
##   - One knob (kT), no cliff: −log(1e-6) ≈ 13.8 is finite and smooth, so the
##     old P_MIN singularity guard collapses into a soft floor.
##
## The two `static func`s below are PURE math (probability + temperature in,
## energy out — no game state). `biome_temperature` is a thin adapter that
## reads a biome's mixedness and feeds the pure `temperature` kernel.

## Soft probability floor. −log(P_FLOOR) ≈ 13.8 — bounded, no divergence.
const P_FLOOR: float = 1e-6


## Surprisal energy of an outcome with probability p at temperature kT.
## Monotonic decreasing in p, additive across independent goods, finite as p→0.
static func surprisal_energy(p: float, kT: float) -> float:
	return -kT * log(clampf(p, P_FLOOR, 1.0))


## Pure temperature law: hotter (more mixed) field → steeper, more volatile
## prices. s_norm ∈ [0,1] is normalized entropy; t_base / t_gain are tunable.
static func temperature(s_norm: float, t_base: float, t_gain: float) -> float:
	return t_base * (1.0 + t_gain * clampf(s_norm, 0.0, 1.0))


## Cost (in pole-emoji units) to DRIVE the field toward/away from a pole whose
## current marginal is p_pole — any Lindblad drive, either direction: invest
## (spark_north/pump) or discharge (spark_south/drain). Forcing the field is work;
## an improbable target (low p_pole) costs more energy = −kT·log p. Floored at 1
## (a drive is never free). The cost-side counterpart of the harvest reward (only
## measurement-extraction rewards; driving the field costs). Pure math.
static func drive_units(p_pole: float, kT: float) -> int:
	return maxi(1, int(round(surprisal_energy(p_pole, kT))))


## Adapter: derive kT from a biome's own mixedness, then hand the numbers to the
## pure `temperature` kernel. s_norm = S / log(dim) ∈ [0,1] from the biome's LIVE
## diagonal entropy (`QuantumComputer.get_entropy`) — NOT from get_purity(), whose
## packed copy the native evolution engine leaves stale (kT would be pinned at the
## init value while the state evolves). Both kT and the reap bank now track the
## same live diagonal.
static func biome_temperature(biome, farm = null) -> float:
	if farm == null:
		push_error("EnergyPricing.biome_temperature requires a farm — market_temperature is loaded config, not a code constant.")
		return 0.0
	# Single source: the loaded config. No code-default fallback.
	var t_base: float = float(BalanceService.get_tuning_value(farm, "market_temperature"))
	var t_gain: float = float(BalanceService.get_tuning_value(farm, "market_temperature_entropy_gain"))
	var s_norm: float = 0.0
	var qc = biome.quantum_computer if biome and "quantum_computer" in biome else null
	if qc and qc.has_method("get_entropy") and qc.has_method("get_dimension"):
		var dim: int = maxi(qc.get_dimension(), 2)
		s_norm = clampf(qc.get_entropy() / log(float(dim)), 0.0, 1.0)
	return temperature(s_norm, t_base, t_gain)
