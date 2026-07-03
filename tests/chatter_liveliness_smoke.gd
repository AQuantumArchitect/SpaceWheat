extends SceneTree

## chatter_liveliness_smoke.gd
##
## Bug-list #4: chatter cadence/diversity must ride the quantum state.
##
## Verifies the new coupling end-to-end at the unit level:
##   1. BiomeMeasurementSampler.measurement_liveliness — Shannon entropy of the
##      measurement distribution, normalized to [0,1]. Peaked → 0 (one thing to
##      say); uniform → 1 (babbles). This stays live for PURE states (unlike von
##      Neumann entropy / purity, which are degenerate in the closed default).
##   2. Socialite.should_chatter — cadence rises monotonically with liveliness.
##   3. SocialiteCluster._pick_biome_from_names — diversity: a livelier biome is
##      picked far more often than a settled one, but the settled one stays
##      reachable (raw weighting, not a gate).

const Socialite := preload("res://Core/Story/Socialite.gd")
const SocialiteCluster := preload("res://Core/Story/SocialiteCluster.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")

var passed: int = 0
var failed: int = 0


# --- Mocks: minimal biome/QC exposing get_basis_state_probabilities() ---------
class MockQC extends RefCounted:
	var states: Array = []
	func get_basis_state_probabilities() -> Array:
		return states

class MockBiome extends RefCounted:
	var quantum_computer = null
	func _init(probs: Array) -> void:
		var qc := MockQC.new()
		for p in probs:
			qc.states.append({"label": "🌾", "probability": float(p)})
		quantum_computer = qc


func _init() -> void:
	print("\n=== Chatter liveliness (bug #4) smoke ===")
	seed(12345)  # deterministic sampling for the Monte-Carlo checks

	# --- 1. measurement_liveliness ------------------------------------------
	var peaked := MockBiome.new([1.0, 0.0, 0.0, 0.0])       # collapsed → 0
	var uniform := MockBiome.new([0.25, 0.25, 0.25, 0.25])  # max spread → 1
	var tilted := MockBiome.new([0.7, 0.1, 0.1, 0.1])       # in between
	var single := MockBiome.new([1.0])                       # 1 outcome → 0

	var live_peaked := BiomeMeasurementSampler.measurement_liveliness(peaked)
	var live_uniform := BiomeMeasurementSampler.measurement_liveliness(uniform)
	var live_tilted := BiomeMeasurementSampler.measurement_liveliness(tilted)
	var live_single := BiomeMeasurementSampler.measurement_liveliness(single)
	var live_null := BiomeMeasurementSampler.measurement_liveliness(null)

	_check(is_equal_approx(live_peaked, 0.0), "peaked distribution → liveliness 0 (got %.3f)" % live_peaked)
	_check(is_equal_approx(live_uniform, 1.0), "uniform distribution → liveliness 1 (got %.3f)" % live_uniform)
	_check(live_tilted > live_peaked and live_tilted < live_uniform, "tilted between peaked and uniform (got %.3f)" % live_tilted)
	_check(is_equal_approx(live_single, 0.0), "single outcome → liveliness 0 (got %.3f)" % live_single)
	_check(is_equal_approx(live_null, 0.0), "null biome → liveliness 0 (safe)")

	# --- 2. should_chatter cadence rises with liveliness --------------------
	var s := Socialite.new("t", "The Demos", "👥")
	s.chattiness = 0.5
	var rate_dead := _chatter_rate(s, 0.5, 0.0, 4000)
	var rate_live := _chatter_rate(s, 0.5, 1.0, 4000)
	_check(rate_live > rate_dead + 0.2, "cadence rises with liveliness (dead=%.2f, live=%.2f)" % [rate_dead, rate_live])
	# Liveliness is the dominant term: a lively settled-personality socialite still
	# out-talks a chatty one voicing a dead biome.
	var shy := Socialite.new("shy", "The Demos", "👥")
	shy.chattiness = 0.2
	var chatty := Socialite.new("chatty", "The Demos", "👥")
	chatty.chattiness = 0.9
	var rate_shy_live := _chatter_rate(shy, 0.3, 1.0, 4000)
	var rate_chatty_dead := _chatter_rate(chatty, 0.3, 0.0, 4000)
	_check(rate_shy_live > rate_chatty_dead, "quantum liveliness dominates personality (shy+live=%.2f > chatty+dead=%.2f)" % [rate_shy_live, rate_chatty_dead])

	# --- 3. diversity: biome pick weighted by liveliness --------------------
	var cluster := SocialiteCluster.new()
	var biomes_dict := {
		"Dead": MockBiome.new([1.0, 0.0, 0.0, 0.0]),      # liveliness 0 → weight 0.1
		"Alive": MockBiome.new([0.25, 0.25, 0.25, 0.25]), # liveliness 1 → weight 1.1
	}
	var names := ["Dead", "Alive"]
	var alive_hits := 0
	var dead_hits := 0
	var trials := 3000
	for _i in range(trials):
		var pick: Dictionary = cluster._pick_biome_from_names(names, biomes_dict)
		if pick.get("biome", null) == biomes_dict["Alive"]:
			alive_hits += 1
		elif pick.get("biome", null) == biomes_dict["Dead"]:
			dead_hits += 1
	# Expected split ≈ 1.1 : 0.1 ≈ 91.7% Alive. Assert a strong but tolerant lean.
	var alive_frac := float(alive_hits) / float(trials)
	_check(alive_frac > 0.8, "livelier biome dominates selection (Alive=%.1f%%)" % (alive_frac * 100.0))
	_check(dead_hits > 0, "settled biome stays reachable — weighted, not gated (Dead hits=%d)" % dead_hits)
	# The winner's liveliness rides along for the caller to reuse in cadence.
	var one: Dictionary = cluster._pick_biome_from_names(["Alive"], biomes_dict)
	_check(is_equal_approx(float(one.get("liveliness", -1.0)), 1.0), "pick returns the winner's liveliness for cadence reuse")

	print("Result: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


## Empirical fraction of ticks where the socialite chatters, over n trials.
func _chatter_rate(s, node_activity: float, liveliness: float, n: int) -> float:
	var hits := 0
	for _i in range(n):
		if s.should_chatter(node_activity, liveliness):
			hits += 1
	return float(hits) / float(n)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s" % label)
