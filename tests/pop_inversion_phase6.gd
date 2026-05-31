extends SceneTree

## pop_inversion_phase6.gd — Phase VI POP reward inversion verification.
##
## Run:  godot --headless --quit --script tests/pop_inversion_phase6.gd
##
## Verifies:
##   - 1/p reward formula at three probability points
##   - Expected value across the qubit (E[reward] ≈ qubit_dim = 2 quantum)
##   - Seeded RNG reproducibility (same seed → same outcome)


var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== POP inversion phase VI ===")
	_t_reward_at_neutral()
	_t_reward_at_rare()
	_t_reward_at_common()
	_t_expected_value_conserved()
	_t_seeded_rng_reproducible()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s" % label)


func _reward_for_p(p: float) -> int:
	# Boltzmann surprisal reward: E = −kT·log p (kT = MARKET_TEMPERATURE_BASE here).
	var kT: float = float(EconomyConstants.MARKET_TEMPERATURE_BASE)
	return maxi(int(round(EnergyPricing.surprisal_energy(p, kT))), 1)


func _t_reward_at_neutral() -> void:
	# p = 0.5 → −10·ln(0.5) ≈ 6.93 → 7 classical (bounded, no 1/p cliff).
	var r = _reward_for_p(0.5)
	_check(r == 7, "p=0.5: reward = 7 classical (got %d)" % r)


func _t_reward_at_rare() -> void:
	# p = 0.01 → −10·ln(0.01) ≈ 46.05 → 46 classical (smooth, not 1000).
	var r = _reward_for_p(0.01)
	_check(r == 46, "p=0.01: rare-side reward = 46 classical (got %d)" % r)


func _t_reward_at_common() -> void:
	# p = 0.99 → −10·ln(0.99) ≈ 0.10 → floored to 1 (common outcomes barely pay).
	var r = _reward_for_p(0.99)
	_check(r == 1, "p=0.99: common-side reward = 1 classical (got %d)" % r)


func _t_expected_value_conserved() -> void:
	# Boltzmann invariant: E[reward] = p·E(p) + (1−p)·E(1−p) = kT·H(p), the qubit's
	# (natural-log) entropy times temperature — the same kT·S law as reap. State-
	# dependent now (max at p=0.5), not a constant. Rounding/floor → ±2 tolerance.
	var kT: float = float(EconomyConstants.MARKET_TEMPERATURE_BASE)
	var p_values: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9]
	var ok = true
	for p in p_values:
		var R_top = float(_reward_for_p(p))
		var R_bot = float(_reward_for_p(1.0 - p))
		var ev = p * R_top + (1.0 - p) * R_bot
		var expected = kT * (-p * log(p) - (1.0 - p) * log(1.0 - p))
		if abs(ev - expected) > 2.0:
			ok = false
			print("    p=%.2f: E[r]=%.2f, expected kT·H ≈ %.2f" % [p, ev, expected])
	_check(ok, "E[reward] ≈ kT·H(p) (entropy law) at p ∈ {0.1, 0.3, 0.5, 0.7, 0.9}")


func _t_seeded_rng_reproducible() -> void:
	# Same seed → same outcome over 100 calls.
	var rng = RandomNumberGenerator.new()
	var seed_val = hash(["test_biome", 7, 12345])
	rng.seed = seed_val
	var first_outcomes: Array = []
	for i in range(100):
		first_outcomes.append(rng.randf() < 0.6)
	rng.seed = seed_val
	var second_outcomes: Array = []
	for i in range(100):
		second_outcomes.append(rng.randf() < 0.6)
	_check(first_outcomes == second_outcomes, "seeded RNG reproducible across 100 calls")
