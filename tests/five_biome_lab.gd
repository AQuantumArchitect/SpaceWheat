extends SceneTree

## Five-biome steady state + 4 pair markets after gene splice:
##   Village, HearthKeepers (bees now), Woodlot, Harbor (sand added), VolcanicFoundry
## Run: godot --headless --quit --script tests/five_biome_lab.gd


const SIM_SECONDS: float = 15.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.05

class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null

func _init() -> void:
	print("\n=== Five-biome lab (post gene-splice) ===\n")
	var root := Node.new()
	root.name = "FiveBiomeLab"
	get_root().add_child(root)

	var br := BiomeRegistry.new()
	var specs := {}
	for bname in ["Village", "HearthKeepers", "Woodlot", "Harbor", "VolcanicFoundry"]:
		var s = br.get_by_name(bname)
		if s == null:
			print("ERROR: biome not found: ", bname)
		specs[bname] = s

	var qcs := {}
	var nodes := {}
	for bname in specs:
		if specs[bname] == null:
			continue
		var res = BiomeBuilder.build_from_spec(specs[bname], root, {"skip_tree_add": true})
		qcs[bname] = res.quantum_computer
		nodes[bname] = res.biome_node

	# Evolve all
	var t := 0.0
	while t < SIM_SECONDS:
		for bname in qcs:
			qcs[bname].evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	# Print marginals
	print("--- Steady-state marginals (pole=1) ---")
	var pairs_to_print := {
		"Village":        ["🔥","🍞","👥"],
		"HearthKeepers":  ["🔥","🍯","🐝","💨","🍞","👥","🪓"],
		"Woodlot":        ["🌲","🌱","🪓","🔥"],
		"Harbor":         ["⚓","🛶","💧","🏜","🪨"],
		"VolcanicFoundry":["🌋","🔥","🪨","💎","🌫","⚡","🏜"],
	}
	for bname in pairs_to_print:
		if not qcs.has(bname):
			continue
		var qc = qcs[bname]
		var parts: Array = []
		for e in pairs_to_print[bname]:
			parts.append("%s=%.3f" % [e, _marg(qc, e)])
		print("  %-20s  %s" % [bname, "  ".join(parts)])

	# Pair markets
	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)

	var market_pairs := [
		["Village", "HearthKeepers"],
		["HearthKeepers", "Woodlot"],
		["Harbor", "VolcanicFoundry"],
		["Village", "Harbor"],
	]

	print("\n--- Pair markets (top 3 offers each) ---")
	for pair in market_pairs:
		var na = pair[0]; var nb = pair[1]
		if not nodes.has(na) or not nodes.has(nb):
			print("  %s⊗%s: missing node" % [na, nb])
			continue
		var offers: Array = lattice.propose_pair_offers(nodes[na], nodes[nb], 6)
		print("  %s ⊗ %s:" % [na, nb])
		if offers.is_empty():
			print("    (no shared emojis — no offers)")
			continue
		for i in range(min(3, offers.size())):
			var o = offers[i]
			var tension = float(o.get_meta("tension", 0.0)) if o.has_meta("tension") else 0.0
			var shared = int(o.get_meta("shared", 0)) if o.has_meta("shared") else 0
			print("    deliver %s  cost ~%.2f %s  tension=%.3f  shared=%d" % [
				o.resource, o.cost_amount, o.cost_emoji, tension, shared])

	root.queue_free()
	print("\n=== lab done ===")
	quit(0)

func _marg(qc, emoji: String) -> float:
	if qc == null or not qc.has(emoji):
		return NAN
	return qc.get_marginal(qc.qubit(emoji), 1)
