extends SceneTree

## tests/wl_drain_sweep.gd — sweep Woodlot Lindblad drain magnitudes
## across [0.25×, 0.5×, 1×, 2×, 4×]. Same shape as hk_drain_sweep but for
## Woodlot, against both Village and HearthKeepers as peers.
##
## Run: godot --headless --quit --script tests/wl_drain_sweep.gd


const SIM_SECONDS: float = 15.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.05
const MULTIPLIERS: Array = [0.25, 1.0, 4.0]


class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null


func _init() -> void:
	print("\n=== Woodlot Lindblad-drain sweep (vs Village + HK peers) ===\n")
	var br := BiomeRegistry.new()
	var v_spec = br.get_by_name("Village")
	var h_spec = br.get_by_name("HearthKeepers")
	var w_spec_orig = br.get_by_name("Woodlot")

	var rows: Array = []
	for mult in MULTIPLIERS:
		rows.append(_run_one(v_spec, h_spec, w_spec_orig, float(mult)))

	# Per-biome WL marginals across multipliers
	print("--- Woodlot marginals across multipliers ---")
	print("  ×rate  | WL 🌲    WL 🌱    WL 🪓    WL 🪵    WL 🔥    WL 🍂")
	print("  -------+-------------------------------------------------------")
	for r in rows:
		print("  %4.2fx  | %.3f   %.3f   %.3f   %.3f   %.3f   %.3f" % [
			r.mult, r.wl_tree, r.wl_seed, r.wl_axe, r.wl_log, r.wl_fire, r.wl_leaf
		])

	# Tensions vs each peer
	print("\n--- Pair tensions across multipliers ---")
	print("  ×rate  | V⊗WL (🔥)   HK⊗WL (🔥+🪓)   notes")
	print("  -------+--------------------------------------")
	for r in rows:
		print("  %4.2fx  | %.3f       %.3f             %s" % [
			r.mult, r.v_wl_tension, r.hk_wl_tension, r.notes
		])

	# Top offers per multiplier
	print("\n--- Top 3 V⊗WL offers per multiplier ---")
	for r in rows:
		print("  ×%.2f:" % r.mult)
		for i in range(min(3, r.v_wl_offers.size())):
			var o = r.v_wl_offers[i]
			print("    %-15s deliver %s  cost %.2f %s  tension %.3f" % [
				o.biome_name, o.resource, o.cost_amount, o.cost_emoji, o.tension
			])

	print("\n--- Top 3 HK⊗WL offers per multiplier ---")
	for r in rows:
		print("  ×%.2f:" % r.mult)
		for i in range(min(3, r.hk_wl_offers.size())):
			var o = r.hk_wl_offers[i]
			print("    %-15s deliver %s  cost %.2f %s  tension %.3f" % [
				o.biome_name, o.resource, o.cost_amount, o.cost_emoji, o.tension
			])

	print("\n=== sweep done ===")
	quit(0)


func _run_one(v_spec, h_spec, w_spec_orig, mult: float) -> Dictionary:
	var root := Node.new()
	root.name = "Run_x%.2f" % mult
	get_root().add_child(root)

	var w_spec: Dictionary = w_spec_orig.to_dict()
	w_spec["atom_components"] = _scale_atom_components(w_spec.get("atom_components", {}), mult)

	var v_res := BiomeBuilder.build_from_spec(v_spec, root, {"skip_tree_add": true})
	var h_res := BiomeBuilder.build_from_spec(h_spec, root, {"skip_tree_add": true})
	var w_res := BiomeBuilder.build_from_spec(w_spec, root, {"skip_tree_add": true})
	var v_qc = v_res.quantum_computer
	var h_qc = h_res.quantum_computer
	var w_qc = w_res.quantum_computer

	var t := 0.0
	while t < SIM_SECONDS:
		v_qc.evolve(STEP_SECONDS, MAX_DT, null)
		h_qc.evolve(STEP_SECONDS, MAX_DT, null)
		w_qc.evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)
	var v_wl_offers_raw: Array = lattice.propose_pair_offers(v_res.biome_node, w_res.biome_node, 6)
	var hk_wl_offers_raw: Array = lattice.propose_pair_offers(h_res.biome_node, w_res.biome_node, 6)
	var v_wl_offers := _digest_offers(v_wl_offers_raw)
	var hk_wl_offers := _digest_offers(hk_wl_offers_raw)

	var v_fire = _marg(v_qc, "🔥")
	var w_fire = _marg(w_qc, "🔥")
	var w_axe = _marg(w_qc, "🪓")
	var h_fire = _marg(h_qc, "🔥")
	var h_axe = _marg(h_qc, "🪓")

	var v_wl_tension: float = abs(v_fire - w_fire)
	var hk_wl_tension: float = abs(h_fire - w_fire) + abs(h_axe - w_axe)

	var notes := ""
	if mult >= 4.0:
		notes = "high drain — saturation likely"
	elif mult <= 0.25:
		notes = "low drain — Hamiltonian dominates"

	root.queue_free()
	return {
		"mult": mult,
		"wl_tree": _marg(w_qc, "🌲"),
		"wl_seed": _marg(w_qc, "🌱"),
		"wl_axe": w_axe,
		"wl_log": _marg(w_qc, "🪵"),
		"wl_fire": w_fire,
		"wl_leaf": _marg(w_qc, "🍂"),
		"v_wl_tension": v_wl_tension,
		"hk_wl_tension": hk_wl_tension,
		"v_wl_offers": v_wl_offers,
		"hk_wl_offers": hk_wl_offers,
		"notes": notes,
	}


func _digest_offers(offers_raw: Array) -> Array:
	var out: Array = []
	for c in offers_raw:
		out.append({
			"biome_name": c.biome_name,
			"resource": c.resource,
			"cost_emoji": c.cost_emoji,
			"cost_amount": c.cost_amount,
			"tension": float(c.get_meta("tension", 0.0)) if c.has_meta("tension") else 0.0,
		})
	return out


func _marg(qc, emoji: String) -> float:
	if qc == null or not qc.has(emoji):
		return NAN
	return qc.get_marginal(qc.qubit(emoji), 1)


func _scale_atom_components(components: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = {}
	for emoji in components:
		var comp: Dictionary = components[emoji]
		var scaled: Dictionary = {}
		for field in comp:
			var v = comp[field]
			if field == "decay" and v is Dictionary:
				var d: Dictionary = v.duplicate()
				if d.has("rate"):
					d["rate"] = float(d["rate"]) * factor
				scaled[field] = d
			elif (field == "lindblad_incoming" or field == "lindblad_outgoing") and v is Dictionary:
				var m: Dictionary = {}
				for k in v:
					m[k] = float(v[k]) * factor
				scaled[field] = m
			elif field == "gated_lindblad_source" and v is Array:
				var arr: Array = []
				for entry in v:
					var e2: Dictionary = entry.duplicate()
					if e2.has("rate"):
						e2["rate"] = float(e2["rate"]) * factor
					arr.append(e2)
				scaled[field] = arr
			else:
				scaled[field] = v
		out[emoji] = scaled
	return out
