class_name SnapshotService
extends Node

## SnapshotService - UI/diagnostic projection layer.
##
## Owns:
## - overlay control for rig/UI diagnostics
## - widget / HUD / overlay snapshots
## - probe-cycle status UI
## - diagnostics that are not part of QuantumInstrument's gameplay API

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

var farm: Node = null
var player_shell: Node = null
var overlay_bridge = null
var instrument = null  # QuantumInstrument (injected by BootManager)
var _probe_status_panel: PanelContainer = null
var _probe_status_label: Label = null
var _probe_status_hide_at_ms: int = 0

const PROBE_STATUS_DURATION_MS: int = 900
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")


func setup(farm_ref: Node, shell_ref: Node) -> void:
	farm = farm_ref
	player_shell = shell_ref
	if not shell_ref:
		return

	if "overlay_manager" in shell_ref:
		overlay_bridge = shell_ref.overlay_manager
	if overlay_bridge:
		overlay_bridge.farm = farm_ref

	if _verbose:
		_verbose.info("instrument", "🎛️", "SnapshotService initialized (farm=%s, shell=%s)" % [
			str(farm_ref.name) if farm_ref else "null",
			str(shell_ref.name) if shell_ref else "null"
		])

	_ensure_probe_status_ui()
	set_process(true)


func inject_instrument(inst) -> void:
	instrument = inst


func reset() -> void:
	# Clear references to scene-tree nodes for restart.
	farm = null
	player_shell = null
	overlay_bridge = null
	instrument = null
	set_process(false)


func _process(_delta: float) -> void:
	if _probe_status_panel and _probe_status_panel.visible and Time.get_ticks_msec() >= _probe_status_hide_at_ms:
		_probe_status_panel.visible = false


func open_quest_board() -> bool:
	return _open_overlay("quests")


func open_icon_panel() -> bool:
	return _open_overlay("atlas")


func open_controls_panel() -> bool:
	return _open_overlay("controls")


func get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	if instrument and instrument.has_method("get_policy_snapshot"):
		var bundled = instrument.get_policy_snapshot(include_offers, include_grid)
		if bundled is Dictionary:
			return bundled
	return {}


func _open_overlay(_name: String) -> bool:
	if not overlay_bridge:
		return false
	return overlay_bridge.open_overlay(_name)


func get_resource_amount(emoji: String) -> float:
	return QuantumInstrumentClass._get_resource_amount(farm, emoji)


func get_batcher_metrics() -> Dictionary:
	# Return batcher health/performance metrics for rig monitoring.
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
	# Return normalized probability map from live IconMap exposure payloads.
	if not farm or not ("biome_evolution_batcher" in farm) or not farm.biome_evolution_batcher:
		return {"ok": false, "error": "no_batcher"}
	var batcher = farm.biome_evolution_batcher
	var payload: Dictionary = {}
	if biome_name == "":
		payload = batcher.get_global_probability_map()
	else:
		payload = batcher.get_biome_probability_map(biome_name)
	return {
		"ok": true,
		"scope": "global" if biome_name == "" else "biome",
		"biome": biome_name,
		"map": payload
	}


func get_lindblad_snapshot(biome_name: String = "", include_populations: bool = true) -> Dictionary:
	# Return no-guess diagnostics for lindblad channels, accumulators, and flux.
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var active_channels: Array = []

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
				if "register_infrastructure" in biome.quantum_computer:
					for reg_key in biome.quantum_computer.register_infrastructure.keys():
						var infra = biome.quantum_computer.register_infrastructure[reg_key]
						if not (infra is Dictionary):
							continue
						if not bool(infra.get("lindblad_pump_active", false)) and not bool(infra.get("lindblad_drain_active", false)):
							continue
						var register_id = int(reg_key)
						var pair = {}
						if farm.has_method("_get_lindblad_pair_for_register"):
							pair = farm._get_lindblad_pair_for_register(biome, register_id)
						elif biome.has_method("get_register_emoji_pair"):
							pair = biome.get_register_emoji_pair(register_id)
						active_channels.append({
							"register_id": register_id,
							"biome": bname,
							"north": str(pair.get("north", "")),
							"south": str(pair.get("south", "")),
							"pump_active": bool(infra.get("lindblad_pump_active", false)),
							"pump_rate": float(infra.get("lindblad_pump_rate", 0.0)),
							"drain_active": bool(infra.get("lindblad_drain_active", false)),
							"drain_rate": float(infra.get("lindblad_drain_rate", 0.0)),
							"drain_accumulator": float(infra.get("lindblad_drain_accumulator", 0.0)),
							"harvest_visible": bool(infra.get("lindblad_harvest_visible", false))
						})
			biomes_data[bname] = {
				"stride": stride,
				"max_evolution_dt": max_dt,
				"sink_fluxes": sink_fluxes,
				"populations": populations
			}

	return {
		"ok": true,
		"biome_filter": biome_name,
		"active_channels": active_channels,
		"active_channel_count": active_channels.size(),
		"active_plot_channels": active_channels,
		"active_plot_count": active_channels.size(),
		"biomes": biomes_data,
		"rainbow_mode": bool(farm._is_rainbow_drain_mode()) if farm and farm.has_method("_is_rainbow_drain_mode") else true,
		"rainbow_accumulators": farm.lindblad_rainbow_accumulators.duplicate(true) if ("lindblad_rainbow_accumulators" in farm) else {}
	}


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
	for wname in ["resources", "action_preview", "quantum_mode", "biome_oval", "quest_board"]:
		var row = get_widget_snapshot(wname)
		if bool(row.get("ok", false)):
			snapshot["widgets"][wname] = row.get("snapshot", {})
	for hname in ["milk_hunter", "performance"]:
		var row = get_hud_snapshot(hname)
		if bool(row.get("ok", false)):
			snapshot["huds"][hname] = row.get("snapshot", {})
	for oname in ["quests", "controls", "signature", "logger", "inspector"]:
		var row = get_overlay_snapshot(oname)
		if bool(row.get("ok", false)):
			snapshot["overlays"][oname] = row.get("snapshot", {})
	return snapshot


func _resolve_overlay_bridge():
	if player_shell and "overlay_manager" in player_shell:
		return player_shell.overlay_manager
	return null


func _resolve_overlay(overlay_name: String):
	if overlay_name == "":
		return null
	var local_bridge = _resolve_overlay_bridge()
	if not local_bridge or not local_bridge.has_method("get_overlay"):
		return null
	return local_bridge.get_overlay(overlay_name)


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


func log_action(action: String, details: Dictionary = {}) -> void:
	if _verbose:
		_verbose.info("instrument", "✍️", "%s %s" % [action, str(details)])


func show_probe_cycle_status(biome_name: String, probe: Dictionary) -> void:
	# Show brief on-screen status for rig-driven probe_cycle.
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
