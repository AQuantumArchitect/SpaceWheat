extends SceneTree

## tests/tensor_village_hearth_lab.gd — Village ⊗ HearthKeepers tensor read.
##
## Experiment #1 of the per-neighborhood (Flavor 2) plan.
## Boots two biomes side by side, evolves them under their own JSONL Hamiltonian
## profiles, and samples paired marginals on the shared and bridge axes.
##
## We deliberately DO NOT couple the two biomes — they evolve independently.
## What we want to learn: how much "tensor signal" already exists from
## structurally similar driven Hamiltonians (shared 🔥/❄ axis, mismatched
## 💨/🍞 pairings, private 💧/🏜 axis).
##
## Run: godot --headless --quit --script tests/tensor_village_hearth_lab.gd


const SIM_SECONDS: float = 30.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.02


func _init() -> void:
	print("\n=== Village ⊗ HearthKeepers tensor lab ===")

	var root := Node.new()
	root.name = "TensorLabRoot"
	get_root().add_child(root)

	var v_res := BiomeBuilder.build_from_registry("Village", root, {"skip_tree_add": true})
	var h_res := BiomeBuilder.build_from_registry("HearthKeepers", root, {"skip_tree_add": true})

	if not v_res.success:
		printerr("Village build failed: %s" % v_res.error)
		quit(1)
		return
	if not h_res.success:
		printerr("HearthKeepers build failed: %s" % h_res.error)
		quit(1)
		return

	var v_qc = v_res.quantum_computer
	var h_qc = h_res.quantum_computer
	print("  Village qubits=%d  HearthKeepers qubits=%d" % [
		v_qc.register_map.num_qubits, h_qc.register_map.num_qubits
	])

	# Resolve qubit indices we'll sample.
	var v_fire := _qubit_for(v_qc, "🔥")     # bridge axis
	var v_bread := _qubit_for(v_qc, "🍞")
	var v_wind := _qubit_for(v_qc, "💨")
	var h_fire := _qubit_for(h_qc, "🔥")
	var h_bread := _qubit_for(h_qc, "🍞")    # paired with 💨 in HK (cross-axis bridge)
	var h_water := _qubit_for(h_qc, "💧")    # private

	if v_fire < 0 or h_fire < 0:
		printerr("Could not resolve fire qubit on both biomes (v=%d h=%d)" % [v_fire, h_fire])
		quit(1)
		return

	# Sample loop — paired marginals for cross-correlation.
	var samples := []
	var t := 0.0
	# Initial sample at t=0
	samples.append(_sample_row(t, v_qc, h_qc, v_fire, v_bread, v_wind, h_fire, h_bread, h_water))
	while t < SIM_SECONDS:
		v_qc.evolve(STEP_SECONDS, MAX_DT, null)
		h_qc.evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS
		samples.append(_sample_row(t, v_qc, h_qc, v_fire, v_bread, v_wind, h_fire, h_bread, h_water))

	# Print tabular trajectory (every 4th sample).
	print("\n  t (s)  | V🔥    H🔥    Δ🔥   | V🍞    H🍞    | V💨    | H💧")
	print("  -------+----------------------+---------------+--------+-------")
	for i in range(samples.size()):
		if i % 4 != 0:
			continue
		var s = samples[i]
		print("  %5.2f  | %.4f  %.4f  %+.3f | %.4f  %.4f | %.4f | %.4f" % [
			s.t, s.v_fire, s.h_fire, s.h_fire - s.v_fire,
			s.v_bread, s.h_bread, s.v_wind, s.h_water
		])

	# Cross-correlation summary: paired ρ(V🔥, H🔥) and ρ(V💨, H🍞).
	var corr_fire := _pearson(samples, "v_fire", "h_fire")
	var corr_cross := _pearson(samples, "v_wind", "h_bread")
	var corr_decoy := _pearson(samples, "v_fire", "h_water")  # private axis sanity

	# Mean absolute deviation on shared 🔥 axis (structural agreement).
	var mad_fire := _mad(samples, "v_fire", "h_fire")

	print("\n  --- summary ---")
	print("  pearson ρ(V🔥, H🔥)  = %+.4f   [shared axis — same drive, same self-energies]" % corr_fire)
	print("  pearson ρ(V💨, H🍞) = %+.4f   [cross bridge — Village reads 💨 alone, HK reads 💨/🍞 as a qubit]" % corr_cross)
	print("  pearson ρ(V🔥, H💧) = %+.4f   [decoy — V🔥 vs HK private moisture; expect low/independent]" % corr_decoy)
	print("  MAD(V🔥, H🔥)       =  %.4f   [shared-axis pointwise drift]" % mad_fire)

	# Perturbation test: drain Village 🔥 hard, watch what HK does next.
	print("\n  --- perturb Village 🔥 (drain pole 1, η=0.5) ---")
	var v_fire_pre: float = v_qc.get_marginal(v_fire, 1)
	var h_fire_pre: float = h_qc.get_marginal(h_fire, 1)
	v_qc.drain_qubit(v_fire, 1, 0.5)
	var v_fire_post: float = v_qc.get_marginal(v_fire, 1)
	var h_fire_post: float = h_qc.get_marginal(h_fire, 1)
	print("  Village 🔥(↑) marginal: %.4f → %.4f  (Δ=%+.4f)" % [v_fire_pre, v_fire_post, v_fire_post - v_fire_pre])
	print("  HK      🔥(↑) marginal: %.4f → %.4f  (Δ=%+.4f)  [should NOT move — biomes uncoupled]" % [h_fire_pre, h_fire_post, h_fire_post - h_fire_pre])

	# Evolve another 5s and observe Village's recovery.
	for _i in range(10):
		v_qc.evolve(STEP_SECONDS, MAX_DT, null)
		h_qc.evolve(STEP_SECONDS, MAX_DT, null)
	var v_fire_after: float = v_qc.get_marginal(v_fire, 1)
	var h_fire_after: float = h_qc.get_marginal(h_fire, 1)
	print("  After 5s evolution post-drain:")
	print("    Village 🔥(↑) = %.4f  (drained by %+.4f, now %+.4f vs pre-drain)" % [
		v_fire_after, v_fire_post - v_fire_pre, v_fire_after - v_fire_pre
	])
	print("    HK      🔥(↑) = %.4f  (drift since perturbation: %+.4f)" % [
		h_fire_after, h_fire_after - h_fire_pre
	])

	print("\n=== tensor lab done ===")
	quit(0)


func _qubit_for(qc, emoji: String) -> int:
	if qc == null or not qc.has(emoji):
		return -1
	return qc.qubit(emoji)


func _sample_row(t: float, v_qc, h_qc, v_fire: int, v_bread: int, v_wind: int,
		h_fire: int, h_bread: int, h_water: int) -> Dictionary:
	return {
		"t": t,
		"v_fire": v_qc.get_marginal(v_fire, 1) if v_fire >= 0 else 0.0,
		"v_bread": v_qc.get_marginal(v_bread, 1) if v_bread >= 0 else 0.0,
		"v_wind": v_qc.get_marginal(v_wind, 1) if v_wind >= 0 else 0.0,
		"h_fire": h_qc.get_marginal(h_fire, 1) if h_fire >= 0 else 0.0,
		"h_bread": h_qc.get_marginal(h_bread, 1) if h_bread >= 0 else 0.0,
		"h_water": h_qc.get_marginal(h_water, 1) if h_water >= 0 else 0.0,
	}


func _pearson(samples: Array, key_a: String, key_b: String) -> float:
	var n := samples.size()
	if n < 2:
		return 0.0
	var mean_a := 0.0
	var mean_b := 0.0
	for s in samples:
		mean_a += float(s[key_a])
		mean_b += float(s[key_b])
	mean_a /= float(n)
	mean_b /= float(n)
	var num := 0.0
	var den_a := 0.0
	var den_b := 0.0
	for s in samples:
		var da = float(s[key_a]) - mean_a
		var db = float(s[key_b]) - mean_b
		num += da * db
		den_a += da * da
		den_b += db * db
	if den_a <= 0.0 or den_b <= 0.0:
		return 0.0
	return num / sqrt(den_a * den_b)


func _mad(samples: Array, key_a: String, key_b: String) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for s in samples:
		total += abs(float(s[key_a]) - float(s[key_b]))
	return total / float(samples.size())
