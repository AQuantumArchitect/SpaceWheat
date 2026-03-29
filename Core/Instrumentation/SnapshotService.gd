class_name SnapshotService
extends Node

## SnapshotService - Shared diagnostics and state snapshot API for UI + headless runners.
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
const GameState = preload("res://Core/GameState/GameState.gd")
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")
const PolicySnapshotBuilder = preload("res://Core/Instrumentation/PolicySnapshotBuilder.gd")
const BiomeAffinityCalc = preload("res://Core/Quantum/BiomeAffinityCalculator.gd")


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
		_verbose.info("instrument", "🎛️", "SnapshotService initialized (farm=%s, shell=%s)" % [
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
	if instrument and instrument.has_method("get_resource_snapshot"):
		var snap = instrument.get_resource_snapshot()
		return snap if snap is Dictionary else {}
	var resources = describe_resources()
	var keys: Array = resources.keys()
	keys.sort()
	return {
		"resources": resources,
		"ordered": keys
	}


func get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	"""Aggregate policy-facing reads into one payload for rigs and UI diagnostics."""
	return PolicySnapshotBuilder.build(self, include_offers, include_grid)


func _build_policy_state_from_snapshot(policy_snapshot: Dictionary, cmd: Dictionary = {}, include_discovery_forecast: bool = true) -> Dictionary:
	var resource_floors = _parse_resource_thresholds(cmd.get("resource_floors", {}))
	var forbid_actions = _parse_forbid_actions(cmd.get("forbid_actions", []))

	var resources = policy_snapshot.get("resources", {})
	if not (resources is Dictionary):
		resources = describe_resources()

	var known_pairs: Array = policy_snapshot.get("known_pairs", [])
	if not (known_pairs is Array):
		known_pairs = get_known_vocab_pairs()

	var offers: Array = policy_snapshot.get("offers", [])
	if not (offers is Array):
		offers = get_quest_offers_for_current_biome()

	var active_quests: Array = policy_snapshot.get("active_quests", [])
	if not (active_quests is Array):
		active_quests = get_active_quests()

	var biomes: Array = policy_snapshot.get("biomes", [])
	if not (biomes is Array):
		biomes = []

	var grid_snapshot = policy_snapshot.get("grid", {})
	if biomes.is_empty() and grid_snapshot is Dictionary:
		var raw_biomes = grid_snapshot.get("biomes", [])
		if raw_biomes is Array:
			for biome_name in raw_biomes:
				var b = str(biome_name)
				if b != "":
					biomes.append(b)

	var locked_offers: Array = policy_snapshot.get("locked_offers", [])
	if not (locked_offers is Array):
		locked_offers = get_locked_offers()

	var lindblad_snapshot = get_lindblad_snapshot("", false)
	var discovery_forecast: Dictionary = {}
	if include_discovery_forecast and farm and farm.has_method("compute_discovery_forecast"):
		discovery_forecast = farm.compute_discovery_forecast()

	_annotate_offer_discovery_affinity(offers)

	return {
		"profile": str(cmd.get("profile", "default")),
		"resources": resources,
		"resource_floors": resource_floors,
		"forbid_actions": forbid_actions,
		"known_pairs": known_pairs,
		"offers": offers,
		"active_quests": active_quests,
		"biomes": biomes,
		"lindblad": lindblad_snapshot,
		"discovery_forecast": discovery_forecast,
		"locked_offers": locked_offers,
	}


func build_policy_state(cmd: Dictionary = {}) -> Dictionary:
	"""Build canonical policy input state for engine-side automation."""
	return _build_policy_state_from_snapshot(get_policy_snapshot(true, true), cmd, true)


func build_policy_state_lightweight(cmd: Dictionary = {}) -> Dictionary:
	"""Build post-action reward state without expensive offer regeneration."""
	var policy_snapshot = get_policy_snapshot(false, true)
	var out = _build_policy_state_from_snapshot(policy_snapshot, cmd, false)
	out["offers"] = []
	out["discovery_forecast"] = {}
	return out


func get_grid_snapshot() -> Dictionary:
	"""Return a minimal grid snapshot for QA turn-by-turn rigs."""
	if instrument and instrument.has_method("get_grid_snapshot"):
		var snap = instrument.get_grid_snapshot()
		return snap if snap is Dictionary else {"ok": false, "error": "invalid_grid_snapshot"}
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var snapshot: Dictionary = {"ok": true}
	if "grid_width" in grid:
		snapshot["grid_width"] = grid.grid_width
	if "grid_height" in grid:
		snapshot["grid_height"] = grid.grid_height
	if grid.has_biomes():
		var biome_names = grid.get_biome_names()
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
	var plots = grid.get_all_plots() if grid.has_method("get_all_plots") else {}
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
	if grid.has_biomes():
		for bkey in grid.get_biome_names():
			var biome = grid.get_biome(str(bkey))
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


func get_recent_resource_mutations(limit: int = 40) -> Array:
	var economy = _get_economy()
	if not economy or not economy.has_method("get_recent_resource_mutations"):
		return []
	return economy.get_recent_resource_mutations(limit)


func get_active_quests() -> Array:
	if instrument and instrument.has_method("get_active_quests"):
		var quests = instrument.get_active_quests()
		return quests if quests is Array else []
	if quest_manager and quest_manager.has_method("get_active_quests"):
		return quest_manager.get_active_quests()
	return []


func get_quest_offers_for_current_biome() -> Array:
	"""Return quest offers for the current biome (does not accept)."""
	if instrument and instrument.has_method("quest_offer_all"):
		var offer_result = instrument.quest_offer_all()
		if offer_result is Dictionary and bool(offer_result.get("ok", false)):
			var offers = offer_result.get("offers", [])
			if offers is Array:
				return offers
	if not quest_manager or not farm:
		return []
	if not quest_manager.has_method("offer_all_faction_quests"):
		return []
	var current_biome = farm.get_current_biome() if farm.has_method("get_current_biome") else null
	if not current_biome and farm.grid and farm.grid.has_biomes():
		current_biome = farm.grid.get_primary_biome()
	if not current_biome:
		return []
	return quest_manager.offer_all_faction_quests(current_biome)


func get_known_vocab_pairs() -> Array:
	if instrument and instrument.has_method("get_known_vocab_pairs"):
		var pairs = instrument.get_known_vocab_pairs()
		return pairs if pairs is Array else []
	if farm and farm.has_method("get_known_pairs"):
		return farm.get_known_pairs()
	return []


func get_known_vocab_emojis() -> Array:
	var pairs = get_known_vocab_pairs()
	return GameState.derive_known_emojis_from_pairs(pairs)
	return []


func get_biome_positions(biome_name: String) -> Array:
	"""Return plot positions for a biome name."""
	if instrument and instrument.has_method("get_biome_positions"):
		var positions = instrument.get_biome_positions(biome_name)
		return positions if positions is Array else []
	if not farm or not ("grid" in farm) or not farm.grid:
		return []
	return farm.grid.get_plot_positions_for_biome(biome_name)


func get_locked_offers() -> Array:
	if instrument and instrument.has_method("quest_locked_offers"):
		var result = instrument.quest_locked_offers()
		var offers = result.get("offers", [])
		return offers if offers is Array else []
	if not quest_manager or not quest_manager.has_method("get_locked_offers"):
		return []
	return quest_manager.get_locked_offers()


func get_overlay_snapshot(overlay_name: String) -> Dictionary:
	var overlay = _resolve_overlay(overlay_name)
	if overlay and overlay.has_method("get_snapshot"):
		return {"ok": true, "overlay": overlay_name, "snapshot": overlay.get_snapshot()}
	return {"ok": false, "error": "overlay_not_found", "overlay": overlay_name}


func get_widget_snapshot(widget_name: String) -> Dictionary:
	var widget = _resolve_widget(widget_name)
	if widget and widget.has_method("get_snapshot"):
		return {"ok": true, "widget": widget_name, "snapshot": widget.get_snapshot()}
	return {"ok": false, "error": "widget_not_found", "widget": widget_name}


func get_hud_snapshot(hud_name: String) -> Dictionary:
	var hud = _resolve_hud(hud_name)
	if hud and hud.has_method("get_snapshot"):
		return {"ok": true, "hud": hud_name, "snapshot": hud.get_snapshot()}
	return {"ok": false, "error": "hud_not_found", "hud": hud_name}


func get_full_ui_snapshot() -> Dictionary:
	var snapshot: Dictionary = {"widgets": {}, "huds": {}, "overlays": {}}
	for wname in ["resources", "action_preview", "quantum_mode", "biome_oval", "quest_board", "faction_browser"]:
		var row = get_widget_snapshot(wname)
		if bool(row.get("ok", false)):
			snapshot["widgets"][wname] = row.get("snapshot", {})
	for hname in ["milk_hunter", "performance"]:
		var row = get_hud_snapshot(hname)
		if bool(row.get("ok", false)):
			snapshot["huds"][hname] = row.get("snapshot", {})
	for oname in ["quests", "controls", "semantic_map", "logger_config", "inspector"]:
		var row = get_overlay_snapshot(oname)
		if bool(row.get("ok", false)):
			snapshot["overlays"][oname] = row.get("snapshot", {})
	return snapshot


func _resolve_overlay_manager():
	if player_shell and "overlay_manager" in player_shell:
		return player_shell.overlay_manager
	return null


func _resolve_overlay(overlay_name: String):
	if overlay_name == "":
		return null
	var overlay_manager = _resolve_overlay_manager()
	if not overlay_manager or not overlay_manager.has_method("get_v2_overlay"):
		return null
	return overlay_manager.get_v2_overlay(overlay_name)


func _resolve_widget(widget_name: String):
	var farm_ui = player_shell.get_farm_ui() if player_shell and player_shell.has_method("get_farm_ui") else null
	match widget_name:
		"resources":
			return farm_ui.resource_panel if farm_ui and "resource_panel" in farm_ui else null
		"action_preview":
			if player_shell and "action_preview_row" in player_shell:
				return player_shell.action_preview_row
			if player_shell and "action_bar_manager" in player_shell and player_shell.action_bar_manager:
				return player_shell.action_bar_manager.action_preview_row
			return null
		"quantum_mode":
			return player_shell.quantum_mode_indicator if player_shell and "quantum_mode_indicator" in player_shell else null
		"biome_oval":
			var overlay = _resolve_overlay("biome_inspector")
			if overlay and "current_biome_panel" in overlay:
				return overlay.current_biome_panel
			return null
		"quest_board":
			var overlay = _resolve_overlay("quests")
			return overlay
		"faction_browser":
			var overlay = _resolve_overlay("quests")
			if overlay and "faction_browser" in overlay:
				return overlay.faction_browser
			return null
	return null


func _resolve_hud(hud_name: String):
	var root = get_tree().root if get_tree() else null
	var farm_view = root.get_node_or_null("FarmView") if root else null
	match hud_name:
		"milk_hunter":
			if farm_view:
				for child in farm_view.get_children():
					if child.has_method("get_snapshot") and child.get_class() == "Control" and "MilkHunter" in child.name:
						return child
					if "milk_hunter" in str(child.name).to_lower():
						return child
			return null
		"performance":
			if farm_view and "performance_hud" in farm_view and farm_view.performance_hud:
				return farm_view.performance_hud
			return _resolve_overlay("inspector")
	return null


func _parse_resource_thresholds(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for key in raw.keys():
		var emoji = str(key)
		if emoji == "":
			continue
		var amount = float(raw.get(key, 0.0))
		if amount > 0.0:
			out[emoji] = amount
	return out


func _parse_forbid_actions(raw) -> Array:
	var forbid_actions: Array = []
	var seen: Dictionary = {}
	if not (raw is Array):
		return forbid_actions
	for item in raw:
		var action_name = str(item)
		if action_name == "" or seen.has(action_name):
			continue
		seen[action_name] = true
		forbid_actions.append(action_name)
	return forbid_actions


func _annotate_offer_discovery_affinity(offers: Array) -> void:
	if offers.is_empty():
		return
	var obs = get_tree().root.get_node_or_null("ObservationFrame")
	var unexplored: Array = obs.get_unexplored_biomes() if obs and obs.has_method("get_unexplored_biomes") else []
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		if north == "" and south == "":
			offer["discovery_affinity"] = 0.0
			continue
		var pair = {"north": north, "south": south}
		var max_aff = 0.0
		for biome_name in unexplored:
			var aff = BiomeAffinityCalc.calculate_affinity_by_name(pair, biome_name)
			if aff > max_aff:
				max_aff = aff
		offer["discovery_affinity"] = max_aff


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
