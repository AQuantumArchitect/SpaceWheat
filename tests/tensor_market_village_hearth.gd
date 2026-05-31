extends SceneTree

## tests/tensor_market_village_hearth.gd — Village ⊗ HearthKeepers market read.
##
## Experiment #2 of the per-neighborhood plan. Builds a minimal tensor-product
## market between two biomes (no cross coupling) and prices contracts on every
## tradable emoji using both biomes' marginals as paired bias sources.
##
## Two scenarios run back-to-back:
##   A. Baseline — HearthKeepers Lindblad rates as authored (mirror Village).
##   B. 10x faction drains — every atom_components rate on HK multiplied by 10.
##      (Still 10x weaker than HK's Hamiltonian couplings — see hearthkeepers.jsonl.)
##
## We tabulate per-emoji P_V, P_HK, tension Δ, market price, and report the
## delta between scenarios.
##
## Run: godot --headless --quit --script tests/tensor_market_village_hearth.gd


const SIM_SECONDS: float = 30.0
const STEP_SECONDS: float = 0.5
const MAX_DT: float = 0.02


func _init() -> void:
	print("\n=== Village ⊗ HearthKeepers tensor market ===")

	var registry := BiomeRegistry.new()
	var v_spec = registry.get_by_name("Village")
	var h_spec = registry.get_by_name("HearthKeepers")
	if v_spec == null or h_spec == null:
		printerr("Failed to load specs (Village=%s, HK=%s)" % [v_spec, h_spec])
		quit(1)
		return

	# --- Scenario A: baseline ----------------------------------------------------
	print("\n--- Scenario A: baseline HK Lindblad ---")
	var price_a: Dictionary = _run_market(v_spec, h_spec)

	# --- Scenario B: 10x HK Lindblad rates --------------------------------------
	print("\n--- Scenario B: HK Lindblad × 5 ---")
	var h_spec_b: Dictionary = h_spec.to_dict()
	h_spec_b["atom_components"] = _scale_atom_components(h_spec_b.get("atom_components", {}), 5.0)
	var price_b: Dictionary = _run_market(v_spec, h_spec_b)

	# --- Diff table -------------------------------------------------------------
	print("\n--- Δ Scenario B − A (price shift, ε=tension change) ---")
	print("  emoji  | P_V (a→b)        P_HK (a→b)       price (a→b)        Δprice    Δtension")
	print("  -------+------------------+-----------------+-------------------+----------+--------")
	var keys: Array = price_a.keys()
	keys.sort()
	for emoji in keys:
		var a = price_a[emoji]
		var b = price_b[emoji]
		print("  %-5s  | %.4f → %.4f  | %.4f → %.4f | %7.2f → %7.2f | %+8.2f | %+.4f" % [
			emoji,
			a.p_v, b.p_v,
			a.p_h, b.p_h,
			a.price, b.price,
			b.price - a.price,
			b.tension - a.tension,
		])

	print("\n=== tensor market done ===")
	quit(0)


## Build, evolve, and price both biomes against each other.
func _run_market(v_spec, h_spec) -> Dictionary:
	var root := Node.new()
	root.name = "MarketRoot_%d" % randi()
	get_root().add_child(root)

	var v_res := BiomeBuilder.build_from_spec(v_spec, root, {"skip_tree_add": true})
	var h_res := BiomeBuilder.build_from_spec(h_spec, root, {"skip_tree_add": true})
	if not v_res.success or not h_res.success:
		printerr("build failure: V=%s  HK=%s" % [v_res.error, h_res.error])
		return {}

	var v_qc = v_res.quantum_computer
	var h_qc = h_res.quantum_computer

	# Settle to quasi-steady state.
	var t := 0.0
	while t < SIM_SECONDS:
		v_qc.evolve(STEP_SECONDS, MAX_DT, null)
		h_qc.evolve(STEP_SECONDS, MAX_DT, null)
		t += STEP_SECONDS

	# Collect all unique emojis on either biome.
	var all_emojis: Array = []
	for e in _emojis_for(v_qc):
		if not all_emojis.has(e):
			all_emojis.append(e)
	for e in _emojis_for(h_qc):
		if not all_emojis.has(e):
			all_emojis.append(e)

	var rows: Dictionary = {}
	print("  emoji  |  P_V    P_HK    Δ        side          price")
	print("  -------+--------------------------------------------------")
	for emoji in all_emojis:
		var p_v: float = _marginal_or_nan(v_qc, emoji)
		var p_h: float = _marginal_or_nan(h_qc, emoji)
		var tension: float = 0.0
		var side: String
		var p_market: float
		var both_have: bool = not is_nan(p_v) and not is_nan(p_h)
		if both_have:
			tension = abs(p_v - p_h)
			p_market = 0.5 * (p_v + p_h)
			side = "both  "
		elif not is_nan(p_v):
			p_market = p_v
			side = "V-only"
		elif not is_nan(p_h):
			p_market = p_h
			side = "H-only"
		else:
			continue

		# Tensor price formula (Boltzmann):
		# 1. Base = surprisal energy −kT·log p of the market marginal.
		# 2. Arbitrage premium: shared-emoji disagreement (tension) adds kT·tension.
		# 3. Single-biome supply gets a structural illiquidity premium (×1.25).
		var kT: float = float(EconomyConstants.MARKET_TEMPERATURE_BASE)
		var price: float = EnergyPricing.surprisal_energy(p_market, kT)
		price += kT * tension
		if not both_have:
			price *= 1.25

		var p_v_disp: String = "  -  " if is_nan(p_v) else "%.3f" % p_v
		var p_h_disp: String = "  -  " if is_nan(p_h) else "%.3f" % p_h
		print("  %-5s  | %s  %s  %.3f    %s        %7.2f" % [
			emoji, p_v_disp, p_h_disp, tension, side, price
		])
		rows[emoji] = {
			"p_v": p_v if not is_nan(p_v) else 0.0,
			"p_h": p_h if not is_nan(p_h) else 0.0,
			"tension": tension,
			"price": price,
			"side": side.strip_edges(),
		}

	root.queue_free()
	return rows


func _marginal_or_nan(qc, emoji: String) -> float:
	if not qc.has(emoji):
		return NAN
	return qc.get_marginal(qc.qubit(emoji), 1)


func _emojis_for(qc) -> Array:
	var out: Array = []
	var n = qc.register_map.num_qubits
	for q in range(n):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north != "":
			out.append(north)
		if south != "":
			out.append(south)
	return out


## Recursively scale all numeric "rate" or scalar Lindblad values in atom_components by `factor`.
func _scale_atom_components(components: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = {}
	for emoji in components:
		var comp: Dictionary = components[emoji]
		var scaled: Dictionary = {}
		for field in comp:
			var v = comp[field]
			# decay: {rate, target}
			if field == "decay" and v is Dictionary:
				var d: Dictionary = v.duplicate()
				if d.has("rate"):
					d["rate"] = float(d["rate"]) * factor
				scaled[field] = d
			# lindblad_incoming / lindblad_outgoing: {emoji: rate}
			elif (field == "lindblad_incoming" or field == "lindblad_outgoing") and v is Dictionary:
				var m: Dictionary = {}
				for k in v:
					m[k] = float(v[k]) * factor
				scaled[field] = m
			# gated_lindblad_source: [{target, gate, rate, power, inverse}]
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
