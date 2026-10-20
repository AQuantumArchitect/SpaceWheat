class_name BiomeDiscoverySubmenu
extends RefCounted

## Captain Add Biome picker — same Q/E/R + F-page grammar as Icon Plant.
## 21 eagles seats the land; a plant-like claim (south good + 🌱) takes control.

const Forecast = preload("res://Core/Gameplay/BiomeDiscoveryForecastService.gd")


static func generate_submenu(biome, farm, page: int = 0, prefer_biome: String = "") -> Dictionary:
	var options = _collect_options(biome, farm)
	if options.is_empty():
		return BaseSubmenu.empty_submenu(
			"biome_discovery",
			"Add Biome",
			"No land in reach"
		)
	options = _pin_preferred(options, prefer_biome, farm)
	options = BaseSubmenu.apply_cost_to_options(options, farm.economy if farm else null)
	var pagination = BaseSubmenu.paginate(options, page)
	var actions = BaseSubmenu.build_actions(pagination.page_options, _build_action)
	return BaseSubmenu.build_result(
		"biome_discovery",
		"Add Biome — pick a land",
		pagination,
		actions
	)


static func _collect_options(biome, farm) -> Array:
	var options: Array = []
	if farm == null or not farm.has_method("can_discover_biome"):
		return options
	var gate: Dictionary = farm.can_discover_biome()
	var unexplored: Array = gate.get("unexplored", [])
	if unexplored.is_empty():
		return options
	var weights: Array = Forecast.compute_weights(farm, unexplored)
	var live_name := ""
	if biome != null and biome.has_method("get_biome_type"):
		live_name = str(biome.get_biome_type())
	var live_atoms: Dictionary = _atom_set(biome)
	for i in range(unexplored.size()):
		var name := str(unexplored[i])
		if name == "":
			continue
		var south := Forecast.claim_south(name)
		# w353 sitting: picker billed 🧊×13 + 🌱×5 on FreshwaterSpring
		# before the land exists (same chicken-egg as BloodLedger 📜/🩸).
		# 21 🦅 seats. South-good plant price is after unlock.
		var cost: Dictionary = ActionCostRuntime.get_action_cost(farm, "discover_biome")
		var shared: Array = _shared_atoms(live_atoms, name)
		var w: float = float(weights[i]) if i < weights.size() else 0.0
		var link := ""
		if not shared.is_empty():
			link = "link %s" % ", ".join(shared.slice(0, 3))
		elif live_name != "":
			link = "no shared atoms with %s" % live_name
		options.append({
			"biome_name": name,
			"south": south,
			"label": name,
			"cost": cost,
			"weight": w,
			"hint": link,
			"enabled": true,
		})
	return BaseSubmenu.sort_by_field(options, "weight", true)


static func _pin_preferred(options: Array, prefer_biome: String, farm) -> Array:
	var needle := str(prefer_biome).strip_edges()
	if needle == "" and farm != null:
		needle = str(Forecast.first_pressured(farm, []))
	if needle == "" or options.is_empty():
		return options
	var pinned: Array = []
	var rest: Array = []
	for option in options:
		if pinned.is_empty() and str(option.get("biome_name", "")) == needle:
			pinned.append(option)
		else:
			rest.append(option)
	return pinned + rest


static func _build_action(option: Dictionary) -> Dictionary:
	return {
		"action": "discover_biome",
		"biome_name": str(option.get("biome_name", "")),
		"south": str(option.get("south", "")),
		"label": str(option.get("label", "")),
		"hint": str(option.get("hint", "")),
		"cost": option.get("cost", {}),
		"cost_display": str(option.get("cost_display", "")),
		"can_afford": bool(option.get("can_afford", true)),
		"enabled": bool(option.get("enabled", true)),
	}


static func _atom_set(biome) -> Dictionary:
	var out: Dictionary = {}
	if biome == null:
		return out
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null or qc.register_map == null:
		return out
	for q in range(qc.register_map.num_qubits):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var n := str(pair.get("north", ""))
		var s := str(pair.get("south", ""))
		if n != "":
			out[n] = true
		if s != "":
			out[s] = true
	return out


static func _shared_atoms(live_atoms: Dictionary, biome_name: String) -> Array:
	var spec = BiomeRegistry.get_shared().get_by_name(biome_name) if BiomeRegistry.get_shared() else null
	if spec == null:
		return []
	var shared: Array = []
	var emojis: Array = spec.emojis if "emojis" in spec else []
	for raw in emojis:
		var e := str(raw)
		if live_atoms.has(e) and not shared.has(e):
			shared.append(e)
	return shared
