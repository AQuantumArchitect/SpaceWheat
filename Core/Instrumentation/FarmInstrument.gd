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
var instrument = null  # QuantumInstrument (injected by BootManager)
var _probe_status_panel: PanelContainer = null
var _probe_status_label: Label = null
var _probe_status_hide_at_ms: int = 0

const PROBE_STATUS_DURATION_MS: int = 900
const PhysicsConfig = preload("res://Core/Config/PhysicsConfig.gd")
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")


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


func inject_instrument(inst) -> void:
	instrument = inst


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
	return QuantumInstrumentClass._get_resource_amount(farm, emoji)


func _get_economy():
	if farm and "economy" in farm and farm.economy:
		return farm.economy
	return null


func describe_resources() -> Dictionary:
	var economy = _get_economy()
	if economy and economy.has_method("get_all_resources"):
		return economy.get_all_resources()
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


func get_batcher_metrics() -> Dictionary:
	"""Return batcher health/performance metrics for rig monitoring."""
	if not farm:
		return {}
	if not ("biome_evolution_batcher" in farm):
		return {}
	var batcher = farm.biome_evolution_batcher
	if not batcher:
		return {}
	if batcher.has_method("get_performance_metrics"):
		return batcher.get_performance_metrics()
	return {}


func get_probability_map(biome_name: String = "") -> Dictionary:
	"""Return normalized probability map from live IconMap exposure payloads."""
	if not farm or not ("biome_evolution_batcher" in farm) or not farm.biome_evolution_batcher:
		return {"ok": false, "error": "no_batcher"}
	var batcher = farm.biome_evolution_batcher
	var payload: Dictionary = {}
	if biome_name == "":
		if batcher.has_method("get_global_probability_map"):
			payload = batcher.get_global_probability_map()
	else:
		if batcher.has_method("get_biome_probability_map"):
			payload = batcher.get_biome_probability_map(biome_name)
	return {
		"ok": true,
		"scope": "global" if biome_name == "" else "biome",
		"biome": biome_name,
		"map": payload
	}


func get_lindblad_snapshot(biome_name: String = "", include_populations: bool = true) -> Dictionary:
	"""Return no-guess diagnostics for lindblad channels, accumulators, and flux."""
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var plots = grid.plots if "plots" in grid else {}
	var plot_channels: Array = []
	var active_plot_count = 0

	for pos in plots.keys():
		var plot = plots[pos]
		if not plot:
			continue
		if not plot.lindblad_pump_active and not plot.lindblad_drain_active:
			continue
		var biome = grid.get_biome_for_plot(pos)
		var bname = ""
		if biome and biome.has_method("get_biome_type"):
			bname = str(biome.get_biome_type())
		elif biome and "name" in biome:
			bname = str(biome.name)
		if biome_name != "" and bname != biome_name:
			continue
		var pair = {}
		if farm.has_method("_get_lindblad_pair_for_plot"):
			pair = farm._get_lindblad_pair_for_plot(plot, pos)
		elif plot.has_method("get_plot_emojis"):
			pair = plot.get_plot_emojis()
		plot_channels.append({
			"grid_pos": {"x": int(pos.x), "y": int(pos.y)},
			"biome": bname,
			"north": str(pair.get("north", "")),
			"south": str(pair.get("south", "")),
			"pump_active": bool(plot.lindblad_pump_active),
			"pump_rate": float(plot.lindblad_pump_rate),
			"drain_active": bool(plot.lindblad_drain_active),
			"drain_rate": float(plot.lindblad_drain_rate),
			"drain_accumulator": float(plot.lindblad_drain_accumulator),
			"harvest_visible": bool(plot._get_infra_field("lindblad_harvest_visible", false)) if plot.has_method("_get_infra_field") else false
		})
		active_plot_count += 1

	var biomes_data: Dictionary = {}
	if "biomes" in grid and grid.biomes:
		for bkey in grid.biomes.keys():
			var biome = grid.biomes[bkey]
			if not biome:
				continue
			var bname = str(bkey)
			if biome_name != "" and bname != biome_name:
				continue
			var stride = int(biome.observation_stride) if "observation_stride" in biome else 1
			var max_dt = float(biome.max_evolution_dt) if "max_evolution_dt" in biome else 0.02
			var sink_fluxes: Dictionary = {}
			var populations: Dictionary = {}
			if biome.quantum_computer:
				if biome.quantum_computer.has_method("get_all_sink_fluxes"):
					sink_fluxes = biome.quantum_computer.get_all_sink_fluxes()
				if include_populations and biome.quantum_computer.has_method("get_all_populations"):
					populations = biome.quantum_computer.get_all_populations()
			biomes_data[bname] = {
				"stride": stride,
				"max_evolution_dt": max_dt,
				"sink_fluxes": sink_fluxes,
				"populations": populations
			}

	return {
		"ok": true,
		"biome_filter": biome_name,
		"active_plot_channels": plot_channels,
		"active_plot_count": active_plot_count,
		"biomes": biomes_data,
		"rainbow_mode": bool(farm._is_rainbow_drain_mode()) if farm and farm.has_method("_is_rainbow_drain_mode") else true,
		"rainbow_accumulators": farm.lindblad_rainbow_accumulators.duplicate(true) if ("lindblad_rainbow_accumulators" in farm) else {}
	}


func add_resource(emoji: String, credits_amount: int, reason: String = "rig_seed") -> bool:
	"""Add emoji-credits directly to economy (used by QA rigs)."""
	var economy = _get_economy()
	if not economy or not economy.has_method("add_resource"):
		return false
	economy.add_resource(emoji, credits_amount, reason)
	return true


func set_resource(emoji: String, credits_amount: int, reason: String = "rig_set") -> bool:
	"""Set emoji-credits to an exact amount (used by deterministic rig seeding)."""
	var economy = _get_economy()
	if not economy or not economy.has_method("set_resource"):
		return false
	economy.set_resource(emoji, credits_amount, reason)
	return true


func get_recent_resource_mutations(limit: int = 40) -> Array:
	var economy = _get_economy()
	if not economy or not economy.has_method("get_recent_resource_mutations"):
		return []
	return economy.get_recent_resource_mutations(limit)


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

const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")


func gate_inject(gate_name: String, positions: Array[Vector2i]) -> Dictionary:
	"""Apply a quantum gate. Always delegates to QuantumInstrument."""
	if instrument:
		return instrument.gate_inject(gate_name, positions)
	push_error("FarmInstrument: no QuantumInstrument available for gate_inject")
	return {"ok": false, "error": "no_instrument"}


func lindblad_pump(positions: Array[Vector2i]) -> Dictionary:
	"""Apply Lindblad drive (pump). Delegates to QuantumInstrument if available."""
	if instrument:
		return instrument.lindblad_pump(positions)
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return LindbladHandler.enable_persistent_drive(farm, positions)


func lindblad_drain(positions: Array[Vector2i]) -> Dictionary:
	"""Apply Lindblad decay (drain). Delegates to QuantumInstrument if available."""
	if instrument:
		return instrument.lindblad_drain(positions)
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return LindbladHandler.enable_persistent_decay(farm, positions)


func time_skip(phrames: int, delta: float = -1.0) -> Dictionary:
	"""Advance simulation phrames deterministically for headless runner usage."""
	if instrument and instrument.has_method("time_skip"):
		return instrument.time_skip(phrames, delta)
	if not farm or not farm.has_method("time_skip_phrames"):
		return {"ok": false, "error": "no_time_skip_support"}
	return farm.time_skip_phrames(phrames, delta if delta > 0.0 else PhysicsConfig.PHRAME_DT)


func set_biome_stride(biome_name: String, stride: int) -> Dictionary:
	"""Set observation stride for a biome. Delegates to QuantumInstrument."""
	if instrument:
		return instrument.set_observation_stride(biome_name, stride)
	return {"ok": false, "error": "no_instrument"}


func set_biome_resolution(biome_name: String, dt: float) -> Dictionary:
	"""Set evolution resolution (dt) for a biome. Delegates to QuantumInstrument."""
	if instrument:
		return instrument.set_resolution(biome_name, dt)
	return {"ok": false, "error": "no_instrument"}


func get_biome_timescale(biome_name: String) -> Dictionary:
	"""Get timescale snapshot for a biome. Delegates to QuantumInstrument."""
	if instrument:
		return instrument.get_timescale_snapshot(biome_name)
	return {"ok": false, "error": "no_instrument"}


func set_timescale_objective(objective: Dictionary) -> Dictionary:
	"""Set shared timescale objective (used by UI + headless runners)."""
	if instrument and instrument.has_method("set_timescale_objective"):
		return instrument.set_timescale_objective(objective)
	return {"ok": false, "error": "no_instrument"}


func get_timescale_objective() -> Dictionary:
	"""Get current timescale objective payload."""
	if instrument and instrument.has_method("get_timescale_objective"):
		return instrument.get_timescale_objective()
	return {"ok": false, "error": "no_instrument"}


func clear_timescale_objective() -> Dictionary:
	"""Reset timescale objective to defaults."""
	if instrument and instrument.has_method("clear_timescale_objective"):
		return instrument.clear_timescale_objective()
	return {"ok": false, "error": "no_instrument"}


func get_timescale_projection(biome_name: String, top_k: int = -1) -> Dictionary:
	"""Project icon-map probabilities + objective scoring for a biome."""
	if instrument and instrument.has_method("get_timescale_projection"):
		return instrument.get_timescale_projection(biome_name, top_k)
	return {"ok": false, "error": "no_instrument"}


func recommend_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	"""Return recommended stride/dt/wait for a biome under current objective."""
	if instrument and instrument.has_method("recommend_timescale"):
		return instrument.recommend_timescale(biome_name, top_k)
	return {"ok": false, "error": "no_instrument"}


func auto_apply_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	"""One-click helper: recommend + apply stride/dt for a biome."""
	if instrument and instrument.has_method("auto_apply_timescale"):
		return instrument.auto_apply_timescale(biome_name, top_k)
	return {"ok": false, "error": "no_instrument"}


func configure_economy(overrides: Dictionary) -> Dictionary:
	"""Apply economy overrides from a world state config.

	Delegates to farm.economy.apply_economy_overrides().
	Returns the result from FarmEconomy.
	"""
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.apply_patch(farm, overrides, "farm_instrument.configure_economy")


func get_balance_snapshot() -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	var snapshot = BalanceService.get_snapshot(farm)
	snapshot["ok"] = true
	return snapshot


func patch_balance(patch: Dictionary, source: String = "farm_instrument.patch_balance") -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.apply_patch(farm, patch, source)


func reset_balance_to_default() -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.reset_to_default(farm)


func export_balance_profile(path: String = "user://saves/balance_profile_last.json") -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	var snapshot = BalanceService.get_snapshot(farm)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"ok": false, "error": "file_open_failed", "path": path}
	file.store_string(JSON.stringify(snapshot, "\t"))
	return {"ok": true, "path": path}


func load_balance_profile(path: String) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if path == "":
		return {"ok": false, "error": "empty_path"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_file", "path": path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"ok": false, "error": "file_open_failed", "path": path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "invalid_json", "path": path}
	var patch = {
		"profile_id": parsed.get("profile_id", "default"),
		"action_costs": parsed.get("action_costs", {}),
		"gate_costs": parsed.get("gate_costs", {}),
		"quest_rewards": parsed.get("quest_rewards", {})
	}
	return BalanceService.apply_patch(farm, patch, "farm_instrument.load_balance_profile")


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
