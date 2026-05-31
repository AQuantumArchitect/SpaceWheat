extends SceneTree
## Harbor cluster lab — 5 biomes around the port:
##   Harbor (neutral ground), SaltRunners, QuayRooks, VolcanicFoundry + Village
## Focus: SR⊗QR boat tension, QR⊗Harbor control surface, SR⊗Harbor evasion
## Run: godot --headless --quit --script tests/harbor_cluster_lab.gd


const SIM_SECONDS: float = 20.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.05

class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null

func _init() -> void:
	print("\n=== Harbor cluster lab ===\n")
	var root := Node.new()
	get_root().add_child(root)
	var br := BiomeRegistry.new()

	var biome_names := ["Harbor", "SaltRunners", "QuayRooks", "VolcanicFoundry", "Village"]
	var qcs := {}
	var nodes := {}
	for bname in biome_names:
		var spec = br.get_by_name(bname)
		if spec == null:
			print("MISSING: ", bname); continue
		var res = BiomeBuilder.build_from_spec(spec, root, {"skip_tree_add": true})
		qcs[bname] = res.quantum_computer
		nodes[bname] = res.biome_node

	var t := 0.0
	while t < SIM_SECONDS:
		for b in qcs: qcs[b].evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	print("--- Steady-state marginals ---")
	var watch := {
		"Harbor":        ["⚓","🛶","💧","🏜","🪨"],
		"SaltRunners":   ["🧂","🛶","💧","⛓","🔓","🔍"],
		"QuayRooks":     ["🚢","⚓","💰","🪝","🛶","📋"],
		"VolcanicFoundry":["🌋","🔥","🪨","💎","🌫","⚡","🏜"],
		"Village":       ["🔥","🍞","👥"],
	}
	for bname in watch:
		if not qcs.has(bname): continue
		var parts: Array = []
		for e in watch[bname]: parts.append("%s=%.3f" % [e, _marg(qcs[bname], e)])
		print("  %-18s  %s" % [bname, "  ".join(parts)])

	# Key pair: SR vs QR (the 🛶 tension)
	print("\n--- 🛶 tension: SaltRunners vs QuayRooks ---")
	var sr_boat = _marg(qcs.get("SaltRunners"), "🛶")
	var qr_boat = _marg(qcs.get("QuayRooks"), "🛶")
	print("  SR.🛶=%.3f  QR.🛶=%.3f  tension=%.3f" % [sr_boat, qr_boat, abs(sr_boat - qr_boat)])

	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)

	var pairs := [
		["SaltRunners", "QuayRooks"],
		["SaltRunners", "Harbor"],
		["QuayRooks", "Harbor"],
		["Harbor", "VolcanicFoundry"],
		["Village", "SaltRunners"],
	]
	print("\n--- Pair markets (top 3 each) ---")
	for pair in pairs:
		var na = pair[0]; var nb = pair[1]
		if not nodes.has(na) or not nodes.has(nb):
			print("  %s⊗%s: missing" % [na, nb]); continue
		var offers: Array = lattice.propose_pair_offers(nodes[na], nodes[nb], 6)
		print("  %s ⊗ %s:" % [na, nb])
		if offers.is_empty():
			print("    (no shared emojis)"); continue
		for i in range(min(3, offers.size())):
			var o = offers[i]
			var tension = float(o.get_meta("tension", 0.0)) if o.has_meta("tension") else 0.0
			var shared = int(o.get_meta("shared", 0)) if o.has_meta("shared") else 0
			print("    deliver %-4s  cost ~%.2f %-4s  tension=%.3f  shared=%d" % [
				o.resource, o.cost_amount, o.cost_emoji, tension, shared])

	root.queue_free()
	print("\n=== cluster lab done ===")
	quit(0)

func _marg(qc, emoji: String) -> float:
	if qc == null or not qc.has(emoji): return NAN
	return qc.get_marginal(qc.qubit(emoji), 1)
