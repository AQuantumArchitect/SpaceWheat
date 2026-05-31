extends SceneTree
## Water-wheat chain lab — BioticFlux → IrrigationJury → Harbor → SR/QR
## Run: godot --headless --quit --script tests/water_wheat_chain_lab.gd


const SIM_SECONDS: float = 20.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.05

class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null

func _init() -> void:
	print("\n=== Water-wheat chain lab ===\n")
	var root := Node.new()
	get_root().add_child(root)
	var br := BiomeRegistry.new()

	var names := ["BioticFlux","IrrigationJury","Harbor","SaltRunners","QuayRooks","Woodlot"]
	var qcs := {}; var nodes := {}
	for n in names:
		var spec = br.get_by_name(n)
		if spec == null: print("MISSING: ", n); continue
		var res = BiomeBuilder.build_from_spec(spec, root, {"skip_tree_add": true})
		qcs[n] = res.quantum_computer
		nodes[n] = res.biome_node

	var t := 0.0
	while t < SIM_SECONDS:
		for n in qcs: qcs[n].evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	print("--- Steady-state marginals ---")
	var watch := {
		"BioticFlux":     ["🌾","🍄","☀","🌙"],
		"IrrigationJury": ["⚖","🌱","💧","🌧","🪣","🌾"],
		"Harbor":         ["🛶","🪝","💧","⚓","🧊","🏜","🪣"],
		"SaltRunners":    ["🛶","💧","⛓"],
		"QuayRooks":      ["🚢","⚓","🛶","📋"],
		"Woodlot":        ["🌲","🌱","🪓","🔥"],
	}
	for n in watch:
		if not qcs.has(n): continue
		var parts: Array = []
		for e in watch[n]: parts.append("%s=%.3f" % [e, _marg(qcs[n], e)])
		print("  %-18s  %s" % [n, "  ".join(parts)])

	# Supply chain tensions
	print("\n--- Supply chain pair markets ---")
	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)
	var pairs := [
		["BioticFlux","IrrigationJury"],
		["IrrigationJury","Harbor"],
		["IrrigationJury","Woodlot"],
		["IrrigationJury","SaltRunners"],
		["Harbor","QuayRooks"],
	]
	for pair in pairs:
		var na = pair[0]; var nb = pair[1]
		if not nodes.has(na) or not nodes.has(nb):
			print("  %s⊗%s: missing" % [na,nb]); continue
		var offers = lattice.propose_pair_offers(nodes[na], nodes[nb], 4)
		print("  %s ⊗ %s:" % [na, nb])
		if offers.is_empty(): print("    (no shared emojis)"); continue
		for i in range(min(3, offers.size())):
			var o = offers[i]
			var t2 = float(o.get_meta("tension",0.0)) if o.has_meta("tension") else 0.0
			print("    deliver %-4s  cost ~%.2f %-4s  tension=%.3f" % [
				o.resource, o.cost_amount, o.cost_emoji, t2])

	root.queue_free()
	print("\n=== chain lab done ===")
	quit(0)

func _marg(qc, emoji: String) -> float:
	if qc == null or not qc.has(emoji): return NAN
	return qc.get_marginal(qc.qubit(emoji), 1)
