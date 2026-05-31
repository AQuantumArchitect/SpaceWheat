extends SceneTree

## tests/hk_drain_sweep.gd — sweep HearthKeepers Lindblad drain magnitudes
## across [0.25×, 0.5×, 1×, 2×, 4×] of the authored values; report what
## each setting does to the V⊗HK market.
##
## For each multiplier we report:
##   • HK steady-state marginals on every emoji (after 30s evolution)
##   • Δmarginal vs Village on shared axis emojis
##   • Tensor-bridge tension (cross-axis 💨/🍞)
##   • Pair-offer prices on representative offers
##
## Run: godot --headless --quit --script tests/hk_drain_sweep.gd


const SIM_SECONDS: float = 30.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.02

const MULTIPLIERS: Array = [0.25, 0.5, 1.0, 2.0, 4.0]


class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null


func _init() -> void:
	print("\n=== HK Lindblad-drain sweep ===\n")
	var br := BiomeRegistry.new()
	var v_spec = br.get_by_name("Village")
	var h_spec_orig = br.get_by_name("HearthKeepers")

	var rows: Array = []
	for mult in MULTIPLIERS:
		var row := _run_one(v_spec, h_spec_orig, float(mult))
		rows.append(row)

	# Summary table
	print("\n--- summary across multipliers ---")
	print("  ×rate  | HK 🔥    HK ❄    HK 💧    HK 🏜    HK 💨    HK 🍞    | tension(🔥,❄)  tension(💨/🍞 bridge)")
	print("  -------+-----------------------------------------------------+----------------------------------")
	for row in rows:
		print("  %4.2fx  | %.3f   %.3f   %.3f   %.3f   %.3f   %.3f   |  %.3f          %.3f" % [
			row.mult,
			row.hk_fire, row.hk_ice, row.hk_water, row.hk_drought, row.hk_wind, row.hk_bread,
			row.tension_fire, row.tension_bread_wind,
		])

	# Pair-offer prices for shared bridge emojis at each multiplier
	print("\n--- pair-offer prices (showing first 3 offers per multiplier) ---")
	for row in rows:
		print("  ×%.2f offers:" % row.mult)
		for i in range(min(3, row.offers.size())):
			var o = row.offers[i]
			print("    %-15s deliver %s  cost %.2f %s  tension %.3f" % [
				o.biome_name, o.resource, o.cost_amount, o.cost_emoji, o.tension
			])

	print("\n=== sweep done ===")
	quit(0)


func _run_one(v_spec, h_spec_orig, mult: float) -> Dictionary:
	var root := Node.new()
	root.name = "Run_x%.2f" % mult
	get_root().add_child(root)

	# Scale HK atom_components rates by mult.
	var h_spec: Dictionary = h_spec_orig.to_dict()
	h_spec["atom_components"] = _scale_atom_components(h_spec.get("atom_components", {}), mult)

	var v_res := BiomeBuilder.build_from_spec(v_spec, root, {"skip_tree_add": true})
	var h_res := BiomeBuilder.build_from_spec(h_spec, root, {"skip_tree_add": true})
	var v_qc = v_res.quantum_computer
	var h_qc = h_res.quantum_computer

	var t := 0.0
	while t < SIM_SECONDS:
		v_qc.evolve(STEP_SECONDS, MAX_DT, null)
		h_qc.evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	# Read marginals.
	var hk_fire: float = _marg(h_qc, "🔥")
	var hk_ice: float = _marg(h_qc, "❄")
	var hk_water: float = _marg(h_qc, "💧")
	var hk_drought: float = _marg(h_qc, "🏜")
	var hk_wind: float = _marg(h_qc, "💨")
	var hk_bread: float = _marg(h_qc, "🍞")
	var v_fire: float = _marg(v_qc, "🔥")
	var v_ice: float = _marg(v_qc, "❄")
	var v_wind: float = _marg(v_qc, "💨")
	var v_bread: float = _marg(v_qc, "🍞")

	var tension_fire: float = abs(v_fire - hk_fire)
	# Cross bridge: V reads 💨 alone (qubit-2 north) and 🍞 alone (qubit-1 south);
	# HK reads them paired on a single qubit. Use sum-of-tensions as proxy.
	var tension_bread_wind: float = abs(v_wind - hk_wind) + abs(v_bread - hk_bread)

	# Run pair offers via a fake farm.
	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	var lattice := MarketLattice.new(farm)
	var offers_raw: Array = lattice.propose_pair_offers(v_res.biome_node, h_res.biome_node, 6)
	var offers: Array = []
	for c in offers_raw:
		offers.append({
			"biome_name": c.biome_name,
			"resource": c.resource,
			"cost_emoji": c.cost_emoji,
			"cost_amount": c.cost_amount,
			"tension": float(c.get_meta("tension", 0.0)) if c.has_meta("tension") else 0.0,
		})

	root.queue_free()
	return {
		"mult": mult,
		"hk_fire": hk_fire, "hk_ice": hk_ice, "hk_water": hk_water,
		"hk_drought": hk_drought, "hk_wind": hk_wind, "hk_bread": hk_bread,
		"tension_fire": tension_fire,
		"tension_bread_wind": tension_bread_wind,
		"offers": offers,
	}


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
