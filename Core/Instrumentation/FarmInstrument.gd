class_name FarmInstrument
extends Node

## FarmInstrument - Bridge between classical resources, the quest/vocabulary UI, and QII tooling.
##
## Provides a single API for external scripts (like the emoji bash runners) to:
##   1. Query economy/output information (resources, farm grid)
##   2. Control modal overlays (quest board, vocabulary)
##   3. Interact with the quest manager (offer, accept, read status)
##
## This node is created by BootManager after FarmUI and the PlayerShell overlays exist.

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

var farm: Node = null
var player_shell: Node = null
var overlay_manager = null
var quest_manager = null
var action_bar_manager = null
var _probe_status_panel: PanelContainer = null
var _probe_status_label: Label = null
var _probe_status_hide_at_ms: int = 0

const PROBE_STATUS_DURATION_MS: int = 900


func setup(farm_ref: Node, shell_ref: Node) -> void:
	farm = farm_ref
	player_shell = shell_ref
	if not shell_ref:
		return

	if "overlay_manager" in shell_ref:
		overlay_manager = shell_ref.overlay_manager
	if "quest_manager" in shell_ref:
		quest_manager = shell_ref.quest_manager
	if overlay_manager:
		overlay_manager.farm = farm_ref
	if "action_bar_manager" in shell_ref:
		action_bar_manager = shell_ref.action_bar_manager

	if _verbose:
		_verbose.info("instrument", "🎛️", "FarmInstrument initialized (farm=%s, shell=%s)" % [
			farm_ref.name if farm_ref else "null",
			shell_ref.name if shell_ref else "null"
		])

	_ensure_probe_status_ui()
	set_process(true)


func _process(_delta: float) -> void:
	if _probe_status_panel and _probe_status_panel.visible and Time.get_ticks_msec() >= _probe_status_hide_at_ms:
		_probe_status_panel.visible = false


func open_quest_board() -> bool:
	return _open_overlay("quests")


func open_vocabulary_panel() -> bool:
	return _open_overlay("vocabulary")


func open_controls_panel() -> bool:
	return _open_overlay("controls")


func _open_overlay(name: String) -> bool:
	if not overlay_manager:
		return false
	return overlay_manager.open_v2_overlay(name)


func get_resource_amount(emoji: String) -> float:
	if farm and "economy" in farm and farm.economy:
		if farm.economy.has_method("get_resource"):
			return farm.economy.get_resource(emoji)
	return 0


func describe_resources() -> Dictionary:
	if farm and "economy" in farm and farm.economy:
		if farm.economy.has_method("get_all_resources"):
			return farm.economy.get_all_resources()
	return {}


func get_resource_snapshot() -> Dictionary:
	"""Return a stable snapshot of resources for turn-by-turn rigs."""
	var resources = describe_resources()
	var keys: Array = resources.keys()
	keys.sort()
	return {
		"resources": resources,
		"ordered": keys
	}


func get_grid_snapshot() -> Dictionary:
	"""Return a minimal grid snapshot for QA turn-by-turn rigs."""
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var snapshot: Dictionary = {"ok": true}
	if "grid_width" in grid:
		snapshot["grid_width"] = grid.grid_width
	if "grid_height" in grid:
		snapshot["grid_height"] = grid.grid_height
	if "biomes" in grid and grid.biomes:
		var biome_names = grid.biomes.keys()
		biome_names.sort()
		snapshot["biomes"] = biome_names
	if snapshot.has("grid_width") and snapshot.has("grid_height"):
		snapshot["plot_count"] = int(snapshot["grid_width"]) * int(snapshot["grid_height"])
	return snapshot


func add_resource(emoji: String, credits_amount: int, reason: String = "rig_seed") -> bool:
	"""Add emoji-credits directly to economy (used by QA rigs)."""
	if not farm or not ("economy" in farm) or not farm.economy:
		return false
	if not farm.economy.has_method("add_resource"):
		return false
	farm.economy.add_resource(emoji, credits_amount, reason)
	return true


func set_resource(emoji: String, credits_amount: int, reason: String = "rig_set") -> bool:
	"""Set emoji-credits to an exact amount (used by deterministic rig seeding)."""
	if not farm or not ("economy" in farm) or not farm.economy:
		return false
	if not farm.economy.has_method("set_resource"):
		return false
	farm.economy.set_resource(emoji, credits_amount, reason)
	return true


func get_recent_resource_mutations(limit: int = 40) -> Array:
	if not farm or not ("economy" in farm) or not farm.economy:
		return []
	if not farm.economy.has_method("get_recent_resource_mutations"):
		return []
	return farm.economy.get_recent_resource_mutations(limit)


func get_active_quests() -> Array:
	if quest_manager and quest_manager.has_method("get_active_quests"):
		return quest_manager.get_active_quests()
	return []


func get_quest_offers_for_current_biome() -> Array:
	"""Return quest offers for the current biome (does not accept)."""
	if not quest_manager or not farm:
		return []
	if not quest_manager.has_method("offer_all_faction_quests"):
		return []
	var current_biome = farm.get_current_biome() if farm.has_method("get_current_biome") else null
	if not current_biome and farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
		current_biome = farm.grid.biomes.values()[0]
	if not current_biome:
		return []
	return quest_manager.offer_all_faction_quests(current_biome)


func accept_quest_data(quest_data: Dictionary) -> bool:
	if not quest_manager:
		return false
	return quest_manager.accept_quest(quest_data)


func complete_quest(quest_id: int) -> bool:
	if not quest_manager:
		return false
	return quest_manager.complete_quest(quest_id)


func complete_or_claim_quest(quest_id: int) -> bool:
	if not quest_manager:
		return false
	if quest_manager.has_method("complete_or_claim"):
		return quest_manager.complete_or_claim(quest_id)
	return false


func claim_quest(quest_id: int) -> bool:
	if not quest_manager:
		return false
	return quest_manager.claim_quest(quest_id)


func get_known_vocab_pairs() -> Array:
	if farm and farm.has_method("get_known_pairs"):
		return farm.get_known_pairs()
	return []


func get_known_vocab_emojis() -> Array:
	if farm and farm.has_method("get_known_emojis"):
		return farm.get_known_emojis()
	return []


func get_biome_positions(biome_name: String) -> Array:
	"""Return plot positions for a biome name."""
	if not farm or not ("grid" in farm) or not farm.grid:
		return []
	if not ("plot_biome_assignments" in farm.grid):
		return []
	var positions: Array = []
	for pos in farm.grid.plot_biome_assignments:
		if farm.grid.plot_biome_assignments[pos] == biome_name:
			positions.append(pos)
	return positions


func accept_quest_by_id(quest_id: int) -> bool:
	if not quest_manager:
		return false
	var quest = quest_manager.get_quest_by_id(quest_id) if quest_manager.has_method("get_quest_by_id") else {}
	if quest.is_empty():
		return false
	return quest_manager.accept_quest(quest)


func offer_all_quests_for_current_biome() -> void:
	if not quest_manager or not farm:
		return
	if not quest_manager.has_method("offer_all_faction_quests"):
		return
	var current_biome = farm.get_current_biome() if farm.has_method("get_current_biome") else null
	if not current_biome and farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
		current_biome = farm.grid.biomes.values()[0]
	if current_biome:
		quest_manager.offer_all_faction_quests(current_biome)


## ============================================================================
## QUANTUM GATE & LINDBLAD OPERATIONS
## ============================================================================

const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")

## Map of rig gate names to GateActionHandler static callables.
const _GATE_DISPATCH: Dictionary = {
	"pauli_x": Callable(GateActionHandler, "apply_pauli_x"),
	"pauli_y": Callable(GateActionHandler, "apply_pauli_y"),
	"pauli_z": Callable(GateActionHandler, "apply_pauli_z"),
	"hadamard": Callable(GateActionHandler, "apply_hadamard"),
	"s_gate": Callable(GateActionHandler, "apply_s_gate"),
	"t_gate": Callable(GateActionHandler, "apply_t_gate"),
	"sdg": Callable(GateActionHandler, "apply_sdg_gate"),
	"tdg": Callable(GateActionHandler, "apply_tdg_gate"),
	"rx": Callable(GateActionHandler, "apply_rx_gate"),
	"ry": Callable(GateActionHandler, "apply_ry_gate"),
	"rz": Callable(GateActionHandler, "apply_rz_gate"),
	"cnot": Callable(GateActionHandler, "apply_cnot"),
	"cz": Callable(GateActionHandler, "apply_cz"),
	"swap": Callable(GateActionHandler, "apply_swap"),
	"bell": Callable(GateActionHandler, "create_bell_pair"),
	"ghz": Callable(GateActionHandler, "create_ghz_state"),
	"cluster": Callable(GateActionHandler, "cluster"),
}


func gate_inject(gate_name: String, positions: Array[Vector2i]) -> Dictionary:
	"""Apply a quantum gate via GateActionHandler.

	gate_name: one of pauli_x, pauli_y, pauli_z, hadamard, s_gate, t_gate,
	           sdg, tdg, rx, ry, rz, cnot, cz, swap, bell, ghz, cluster
	positions: grid positions (Vector2i) to target
	"""
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not _GATE_DISPATCH.has(gate_name):
		return {"ok": false, "error": "unknown_gate", "gate": gate_name, "available": _GATE_DISPATCH.keys()}
	var gate_callable = _GATE_DISPATCH[gate_name] as Callable
	if gate_callable == null or not gate_callable.is_valid():
		return {"ok": false, "error": "invalid_gate_dispatch", "gate": gate_name}
	var result = gate_callable.call(farm, positions)
	result["gate"] = gate_name
	return result


func lindblad_pump(positions: Array[Vector2i]) -> Dictionary:
	"""Apply Lindblad drive (pump) to increase population at positions."""
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return LindbladHandler.lindblad_drive(farm, positions)


func lindblad_drain(positions: Array[Vector2i]) -> Dictionary:
	"""Apply Lindblad decay (drain) to decrease population at positions."""
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return LindbladHandler.lindblad_decay(farm, positions)


func configure_economy(overrides: Dictionary) -> Dictionary:
	"""Apply economy overrides from a world state config.

	Delegates to farm.economy.apply_economy_overrides().
	Returns the result from FarmEconomy.
	"""
	if not farm or not ("economy" in farm) or not farm.economy:
		return {"ok": false, "error": "no_economy"}
	if not farm.economy.has_method("apply_economy_overrides"):
		return {"ok": false, "error": "method_not_available"}
	var applied = farm.economy.apply_economy_overrides(overrides)
	return {"ok": true, "applied": applied}


func log_action(action: String, details: Dictionary = {}) -> void:
	if _verbose:
		_verbose.info("instrument", "✍️", "%s %s" % [action, str(details)])


func show_probe_cycle_status(biome_name: String, probe: Dictionary) -> void:
	"""Show brief on-screen status for rig-driven probe_cycle."""
	if not _probe_status_label or not _probe_status_panel:
		return

	var success = bool(probe.get("success", false))
	var stage = str(probe.get("stage", ""))
	var status_prefix = "🔁 Probe"
	var biome = biome_name if biome_name != "" else "?"
	var status_text = "%s %s" % [status_prefix, biome]

	if success:
		status_text += "  Q✓ E✓ R✓"
	else:
		if stage == "":
			stage = "unknown"
		status_text += "  ✖ %s" % stage

	_probe_status_label.text = status_text
	_probe_status_panel.visible = true
	_probe_status_hide_at_ms = Time.get_ticks_msec() + PROBE_STATUS_DURATION_MS


func _ensure_probe_status_ui() -> void:
	if _probe_status_panel or not player_shell:
		return

	var host: Node = player_shell
	if player_shell.has_node("OverlayLayer"):
		host = player_shell.get_node("OverlayLayer")

	var panel := PanelContainer.new()
	panel.name = "RigProbeStatus"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 52)
	panel.custom_minimum_size = Vector2(260, 30)

	var label := Label.new()
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = ""
	panel.add_child(label)

	host.add_child(panel)
	_probe_status_panel = panel
	_probe_status_label = label
