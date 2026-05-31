extends SceneTree

## tests/three_biome_lab.gd — three-biome unitary peer observation.
## Builds Village + HearthKeepers + Woodlot, evolves all three independently
## under their authored Lindbladians, and reports the three pair markets
## (V⊗HK, V⊗WL, HK⊗WL) at steady state. No intervention, no parameter
## sweeping — just "what does the natural shape look like?"
##
## Run: godot --headless --quit --script tests/three_biome_lab.gd


const SIM_SECONDS: float = 30.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.02


class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null


func _init() -> void:
	print("\n=== Three-biome lab · V / HK / WL ===\n")
	var br := BiomeRegistry.new()
	var biomes_specs: Dictionary = {
		"Village": br.get_by_name("Village"),
		"HearthKeepers": br.get_by_name("HearthKeepers"),
		"Woodlot": br.get_by_name("Woodlot"),
	}
	for name in biomes_specs.keys():
		if biomes_specs[name] == null:
			printerr("missing spec: %s" % name)
			quit(1)
			return

	var root := Node.new()
	get_root().add_child(root)
	var biomes: Dictionary = {}
	for name in biomes_specs.keys():
		var res = BiomeBuilder.build_from_spec(biomes_specs[name], root, {"skip_tree_add": true})
		if not res.success:
			printerr("build %s failed: %s" % [name, res.error])
			quit(1)
			return
		biomes[name] = res.biome_node

	# Settle all three
	var t := 0.0
	while t < SIM_SECONDS:
		for name in biomes.keys():
			biomes[name].quantum_computer.evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	# Per-biome marginal report
	print("--- Per-biome steady-state marginals (after %ds) ---" % int(SIM_SECONDS))
	for name in biomes.keys():
		var b = biomes[name]
		print("  %-15s qubits=%d" % [name, b.quantum_computer.register_map.num_qubits])
		var m = _emoji_marginals(b.quantum_computer)
		var keys = m.keys()
		keys.sort()
		var line := "    "
		for e in keys:
			line += "%s %.3f  " % [e, float(m[e])]
		print(line)

	# Pair markets
	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)

	var pair_names: Array = [
		["Village", "HearthKeepers"],
		["Village", "Woodlot"],
		["HearthKeepers", "Woodlot"],
	]
	print("\n--- Three pair markets ---")
	for pair in pair_names:
		var a: String = pair[0]
		var b: String = pair[1]
		var offers: Array = lattice.propose_pair_offers(biomes[a], biomes[b], 6)
		var shared: Array = _shared_emojis(biomes[a], biomes[b])
		var total_tension: float = _pair_tension_total(biomes[a], biomes[b])
		print("\n  %s ⊗ %s   shared: [%s]   total tension: %.3f" % [a, b, " ".join(shared), total_tension])
		print("    %-3s %-15s %-7s %-9s %-10s %-7s %-7s" % ["#", "settle biome", "deliver", "cost emoji", "cost qty", "tension", "shared"])
		for i in range(offers.size()):
			var c = offers[i]
			var tension = c.get_meta("tension", 0.0) if c.has_meta("tension") else 0.0
			var sh = c.get_meta("shared", false) if c.has_meta("shared") else false
			print("    %-3d %-15s %-7s %-9s %-10.2f %-7.3f %s" % [
				i + 1, c.biome_name, c.resource, c.cost_emoji, c.cost_amount, tension, "yes" if sh else "no"
			])

	print("\n=== three-biome lab done ===")
	quit(0)


func _emoji_marginals(qc) -> Dictionary:
	var out: Dictionary = {}
	if qc == null or qc.register_map == null:
		return out
	var n = qc.register_map.num_qubits
	for q in range(n):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		var p1: float = qc.get_marginal(q, 1) if qc.has_method("get_marginal") else 0.5
		if north != "":
			out[north] = 1.0 - p1
		if south != "":
			out[south] = p1
	return out


func _shared_emojis(a, b) -> Array:
	var ma: Dictionary = _emoji_marginals(a.quantum_computer)
	var mb: Dictionary = _emoji_marginals(b.quantum_computer)
	var shared: Array = []
	for e in ma.keys():
		if mb.has(e):
			shared.append(e)
	shared.sort()
	return shared


func _pair_tension_total(a, b) -> float:
	var ma: Dictionary = _emoji_marginals(a.quantum_computer)
	var mb: Dictionary = _emoji_marginals(b.quantum_computer)
	var total: float = 0.0
	for e in ma.keys():
		if mb.has(e):
			total += abs(float(ma[e]) - float(mb[e]))
	return total
