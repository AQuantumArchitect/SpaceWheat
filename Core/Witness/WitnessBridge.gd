extends Node

## WitnessBridge — the Witness's sensor membrane. Autoloaded. Subscribes to
## PLAYER-VISIBLE game signals only (the same events that drive toasts, the
## event log, and on-screen state) and translates each into a weak observation
## on WitnessOrgan. This is the parity law made structural: the Witness never
## reads ground-truth ρ, viz caches, or biome internals — fog-of-war IS weak
## measurement, and scouting is the only way to buy detector efficiency.
##
## Pattern cloned from PlayerEventBridge: rewires on EVERY farm_ready (which
## GameStateManager emits on BOTH the boot lane and the path-load lane — fix
## 32fc633e), _connect_once-guarded against double-connects.
##
## Which observation each signal fires — target z, strength α — is DATA in
## witness_spec.json bindings, not code here. This file only routes.

var _farm: Node = null
var _quest_manager: Node = null
var _economy: Node = null
var _active_biome: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if GameStateManager and GameStateManager.has_signal("farm_ready"):
		GameStateManager.farm_ready.connect(_on_farm_ready)
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_signal("active_biome_changed"):
		abm.active_biome_changed.connect(_on_active_biome_changed)


func _on_farm_ready(farm: Node, _state) -> void:
	if farm == null or farm == _farm:
		return
	_farm = farm
	_quest_manager = _resolve(farm, "quest_manager")
	_economy = _resolve(farm, "economy")

	_connect_once(_farm, "terminal_measured", _on_terminal_measured)
	_connect_once(_farm, "plot_revealed", _on_plot_revealed)
	_connect_once(_farm, "biome_loaded", _on_biome_loaded)
	_connect_once(_farm, "standing_changed", _on_standing_changed)
	_connect_once(_economy, "resource_mutated", _on_resource_mutated)
	_connect_once(_economy, "purchase_failed", _on_purchase_failed)
	_connect_once(_quest_manager, "quest_completed", _on_quest_completed)
	_connect_once(_quest_manager, "quest_failed", _on_quest_failed)
	_connect_once(_quest_manager, "quest_expired", _on_quest_expired)

	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("get_active_biome"):
		_set_active_biome(str(abm.get_active_biome()))


func _resolve(farm: Node, prop: String) -> Node:
	if prop in farm:
		var v = farm.get(prop)
		return v if v is Node else null
	return null


func _connect_once(obj: Object, sig: String, cb: Callable) -> void:
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


## ── routing helpers ─────────────────────────────────────────────────────────

func _observe(sensor_id: String, zone: String, value: float, confidence: float = 1.0) -> void:
	var binding := WitnessSpec.binding_for(WitnessOrgan.spec, sensor_id)
	if binding.is_empty():
		return
	var role := str(binding.get("role", ""))
	var z := WitnessSpec.normalize(binding, value)
	var alpha := WitnessSpec.binding_alpha(WitnessOrgan.spec, binding) * clampf(confidence, 0.0, 1.0)
	WitnessOrgan.observe(zone, role, z, alpha, confidence)


func _set_active_biome(biome_name: String) -> void:
	if biome_name.is_empty():
		return
	_active_biome = biome_name
	WitnessOrgan.ensure_biome_cluster(biome_name)


func _biome_zone_for_plot(grid_pos: Vector2i) -> String:
	# The plot→biome assignment is player-visible presentation (the bubble's
	# biome label in the seat's field payload) — legal for routing.
	if _farm and _farm.get("grid") != null:
		var assignments: Dictionary = _farm.grid.get_plot_biome_assignments()
		var biome := str(assignments.get(grid_pos, ""))
		if not biome.is_empty():
			WitnessOrgan.ensure_biome_cluster(biome)
			return "biome:%s" % biome
	return "biome:%s" % _active_biome


## ── handlers ────────────────────────────────────────────────────────────────

func _on_terminal_measured(grid_pos: Vector2i, _terminal_id: String, outcome: String, _probability: float) -> void:
	var zone := _biome_zone_for_plot(grid_pos)
	# Polarity from the plot's remembered axis — what the player just read off
	# the popped bubble. Unknown axis → equator (direction unknown, event seen).
	var z := 0.0
	if _farm and _farm.get("grid") != null:
		var plot = _farm.grid.get_plot(grid_pos)
		if plot and plot.has_method("get_measurement_memory"):
			var memory: Dictionary = plot.get_measurement_memory()
			if bool(memory.get("has_memory", false)):
				z = 1.0 if outcome == str(memory.get("north_emoji", "")) else -1.0
	var binding := WitnessSpec.binding_for(WitnessOrgan.spec, "terminal_measured")
	if not binding.is_empty():
		WitnessOrgan.observe(zone, str(binding.get("role", "outcome")), z,
			WitnessSpec.binding_alpha(WitnessOrgan.spec, binding))
	_observe("terminal_measured.freshness", zone, 1.0)


func _on_plot_revealed(grid_pos: Vector2i) -> void:
	_observe("plot_revealed", _biome_zone_for_plot(grid_pos), 1.0)


func _on_biome_loaded(biome_name: String, _biome_ref) -> void:
	WitnessOrgan.ensure_biome_cluster(biome_name)
	_observe("biome_loaded", "self", 1.0)


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	_set_active_biome(new_biome)
	_observe("biome_loaded", "self", 1.0)


func _on_resource_mutated(emoji: String, delta: float, reason: String, _new_amount: float) -> void:
	var spec: Dictionary = WitnessOrgan.spec
	var harvest := WitnessSpec.binding_for(spec, "resource_mutated.harvest")
	if not harvest.is_empty() and (harvest.get("reasons", []) as Array).has(reason):
		_observe("resource_mutated.harvest", "biome:%s" % _active_biome, delta)
	var drain := WitnessSpec.binding_for(spec, "resource_mutated.drain")
	if not drain.is_empty() and (drain.get("reasons", []) as Array).has(reason):
		_observe("resource_mutated.drain", "biome:%s" % _active_biome, 1.0)
	# 🍼/🌱-style ambient trickles and spends alike move the wealth trend.
	if emoji != "":
		_observe("resource_mutated.any", "self", delta)


func _on_purchase_failed(_reason: String) -> void:
	_observe("purchase_failed", "self", 1.0)


func _on_quest_completed(_qid: int, _rewards: Dictionary) -> void:
	_observe("quest_completed", "self", 1.0)


func _on_quest_failed(_qid: int, _reason: String) -> void:
	_observe("quest_failed", "self", 1.0)


func _on_quest_expired(_qid: int) -> void:
	_observe("quest_expired", "self", 1.0)


func _on_standing_changed(_faction: String, _channel: String, delta: float, _new_value: float) -> void:
	_observe("standing_changed", "self", delta)
