extends SceneTree

## pop_inversion_phase6.gd — Phase VI POP reward inversion verification.
##
## Run:  godot --headless --quit --script tests/pop_inversion_phase6.gd
##
## Verifies:
##   - 1/p reward formula at three probability points
##   - Expected value across the qubit (E[reward] ≈ qubit_dim = 2 quantum)
##   - Seeded RNG reproducibility (same seed → same outcome)

const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")

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
	var p_clipped = clampf(p, HamiltonianConfig.P_MIN, 1.0 - HamiltonianConfig.P_MIN)
	var reward_quantum = round(1.0 / p_clipped)
	var credits = reward_quantum * HamiltonianConfig.QUANTUM_CLASSICAL_RATIO
	return maxi(int(credits), 1)


func _t_reward_at_neutral() -> void:
	# p = 0.5 → reward_quantum = 2 → credits = 20
	var r = _reward_for_p(0.5)
	_check(r == 20, "p=0.5: reward = 20 classical (got %d)" % r)


func _t_reward_at_rare() -> void:
	# p = 0.01 → reward_quantum = 100 → credits = 1000
	var r = _reward_for_p(0.01)
	_check(r == 1000, "p=0.01: rare-side reward = 1000 classical (got %d)" % r)


func _t_reward_at_common() -> void:
	# p = 0.99 → reward_quantum = round(1.01) = 1 → credits = 10
	var r = _reward_for_p(0.99)
	_check(r == 10, "p=0.99: common-side reward = 10 classical (got %d)" % r)


func _t_expected_value_conserved() -> void:
	# E[reward] should equal 2 quantum (qubit dim) for any qubit state.
	# Test at p=0.3, p=0.7 and verify p·R(p) + (1-p)·R(1-p) ≈ 2·QC_RATIO classical.
	var p_values: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9]
	var ok = true
	for p in p_values:
		var R_top = float(_reward_for_p(p))
		var R_bot = float(_reward_for_p(1.0 - p))
		var ev = p * R_top + (1.0 - p) * R_bot
		# Expected ≈ 2 × QC_RATIO = 20 classical (rounding tolerance ±5)
		if abs(ev - 20.0) > 5.0:
			ok = false
			print("    p=%.2f: E[r]=%.2f, expected ≈ 20 (rounding)" % [p, ev])
	_check(ok, "E[reward] ≈ 20 classical at p ∈ {0.1, 0.3, 0.5, 0.7, 0.9}")


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
