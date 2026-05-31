#!/usr/bin/env -S godot -s
extends SceneTree


const PROFILE_MONITORS := {
	"fps": Performance.TIME_FPS,
	"time_process_ms": Performance.TIME_PROCESS,
	"time_physics_ms": Performance.TIME_PHYSICS_PROCESS,
	"memory_static": Performance.MEMORY_STATIC,
	"object_count": Performance.OBJECT_COUNT,
	"object_node_count": Performance.OBJECT_NODE_COUNT,
}

const DEFAULT_WARMUP_FRAMES := 90
const DEFAULT_SAMPLE_FRAMES := 240
const DEFAULT_DENSE_TERMINALS := 4
const DEFAULT_MULTI_BIOMES := 4

var _profile_mode := "single"
var _output_path := ""
var _warmup_frames := DEFAULT_WARMUP_FRAMES
var _sample_frames := DEFAULT_SAMPLE_FRAMES
var _dense_terminals := DEFAULT_DENSE_TERMINALS
var _multi_biomes := DEFAULT_MULTI_BIOMES


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_configure_from_env()

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm")
		quit(2)
		return

	var main_scene = load("res://scenes/Main.tscn")
	if main_scene == null:
		printerr("no Main.tscn")
		quit(3)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame

	var app_root = await _wait_for_app_root()
	if app_root == null:
		printerr("app root timeout")
		quit(3)
		return

	await app_root.start_game({"slot": -1, "scenario_id": "new_game_easy", "headless": false})
	var farm_view = app_root.game_root.farm_view if app_root.game_root else null

	var farm = await _wait_for_farm(gsm)
	if farm == null:
		printerr("farm boot timeout")
		quit(4)
		return

	var quantum_viz = await _wait_for_quantum_viz(farm_view)
	if quantum_viz == null:
		printerr("quantum viz timeout")
		quit(5)
		return

	var instrument = await _wait_for_instrument(farm)
	if instrument == null:
		printerr("instrument timeout")
		quit(6)
		return

	var scenario := await _apply_profile_mode(farm, instrument, quantum_viz)
	if not scenario.get("ok", false):
		printerr("profile setup failed: %s" % scenario.get("error", "unknown"))
		quit(7)
		return

	for _i in range(_warmup_frames):
		await process_frame

	var report := await _capture_profile_report(farm, quantum_viz, scenario)
	_write_report(report)
	_print_report_summary(report)

	await gsm.session_lifecycle.shutdown_session(true, true)
	await process_frame
	await process_frame
	quit(0)


func _configure_from_env() -> void:
	_profile_mode = OS.get_environment("PROFILE_MODE").strip_edges().to_lower()
	if _profile_mode == "":
		_profile_mode = "single"
	_output_path = OS.get_environment("PROFILE_OUTPUT_PATH").strip_edges()
	_warmup_frames = int(OS.get_environment("PROFILE_WARMUP_FRAMES")) if OS.get_environment("PROFILE_WARMUP_FRAMES") != "" else DEFAULT_WARMUP_FRAMES
	_sample_frames = int(OS.get_environment("PROFILE_SAMPLE_FRAMES")) if OS.get_environment("PROFILE_SAMPLE_FRAMES") != "" else DEFAULT_SAMPLE_FRAMES
	_dense_terminals = int(OS.get_environment("PROFILE_DENSE_TERMINALS")) if OS.get_environment("PROFILE_DENSE_TERMINALS") != "" else DEFAULT_DENSE_TERMINALS
	_multi_biomes = int(OS.get_environment("PROFILE_MULTI_BIOMES")) if OS.get_environment("PROFILE_MULTI_BIOMES") != "" else DEFAULT_MULTI_BIOMES


func _wait_for_farm(gsm) -> Node:
	for _i in range(240):
		var farm = gsm.get_active_farm() if gsm.has_method("get_active_farm") else gsm.active_farm
		if farm and farm.grid and farm.terminal_pool:
			return farm
		await process_frame
	return null


func _wait_for_app_root() -> Node:
	for _i in range(120):
		var nodes = get_nodes_in_group("app_root")
		if nodes.size() > 0:
			return nodes[0]
		await process_frame
	return null


func _wait_for_quantum_viz(farm_view) -> Node:
	for _i in range(240):
		if farm_view and is_instance_valid(farm_view) and farm_view.quantum_viz:
			return farm_view.quantum_viz
		await process_frame
	return null


func _wait_for_instrument(farm) -> Object:
	for _i in range(240):
		if farm and farm.instrument:
			return farm.instrument
		await process_frame
	return null


func _apply_profile_mode(farm, instrument, quantum_viz) -> Dictionary:
	match _profile_mode:
		"dormant":
			return {
				"ok": true,
				"mode": _profile_mode,
				"explored": [],
				"description": "booted headed runtime with no explored terminals"
			}
		"single":
			var single_biome := _resolve_biome_name(farm)
			if single_biome == "":
				return {"ok": false, "error": "no_biome"}
			var single_pos := _resolve_plot_position(farm, single_biome)
			if single_pos == GridSentinel.INVALID_POSITION:
				return {"ok": false, "error": "no_plot"}
			var one = await _explore_positions(instrument, quantum_viz, [{ "biome": single_biome, "pos": single_pos }])
			one["description"] = "one active biome with one bound terminal"
			return one
		"dense":
			var dense_biome := _resolve_biome_name(farm)
			if dense_biome == "":
				return {"ok": false, "error": "no_biome"}
			var dense_targets := []
			for pos in _resolve_plot_positions(farm, dense_biome, _dense_terminals):
				dense_targets.append({ "biome": dense_biome, "pos": pos })
			if dense_targets.is_empty():
				return {"ok": false, "error": "no_dense_targets"}
			var dense = await _explore_positions(instrument, quantum_viz, dense_targets)
			dense["description"] = "one active biome with %d bound terminals" % dense_targets.size()
			return dense
		"multi":
			var multi_targets := []
			for biome_name in _resolve_biome_names(farm, _multi_biomes):
				var pos := _resolve_plot_position(farm, biome_name)
				if pos != GridSentinel.INVALID_POSITION:
					multi_targets.append({ "biome": biome_name, "pos": pos })
			if multi_targets.is_empty():
				return {"ok": false, "error": "no_multi_targets"}
			var multi = await _explore_positions(instrument, quantum_viz, multi_targets)
			multi["description"] = "%d active biomes with one bound terminal each" % multi_targets.size()
			return multi
		_:
			return {"ok": false, "error": "unknown_mode_%s" % _profile_mode}


func _explore_positions(instrument, quantum_viz, targets: Array) -> Dictionary:
	var explored := []
	for target in targets:
		var biome_name := str(target.get("biome", ""))
		var pos: Vector2i = target.get("pos", GridSentinel.INVALID_POSITION)
		if biome_name == "" or pos == GridSentinel.INVALID_POSITION:
			continue
		var result = instrument.action_explore(biome_name, pos)
		if not result.get("success", false):
			return {
				"ok": false,
				"error": "explore_failed_%s_%s" % [biome_name, str(pos)],
				"message": result.get("message", "unknown")
			}
		var bubble_ok = await _wait_for_bubble(quantum_viz, pos)
		if not bubble_ok:
			return {
				"ok": false,
				"error": "bubble_timeout_%s_%s" % [biome_name, str(pos)]
			}
		explored.append({
			"biome": biome_name,
			"grid_pos": {"x": pos.x, "y": pos.y}
		})

	return {
		"ok": true,
		"mode": _profile_mode,
		"explored": explored
	}


func _capture_profile_report(farm, quantum_viz, scenario: Dictionary) -> Dictionary:
	if quantum_viz and quantum_viz.has_method("reset_performance_breakdown"):
		quantum_viz.reset_performance_breakdown()

	var monitor_samples := []
	var batcher_samples := []
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher and batcher.has_method("reset_performance_metrics"):
		batcher.reset_performance_metrics()

	for frame_idx in range(_sample_frames):
		await process_frame

		var monitor_sample := {
			"frame": frame_idx + 1,
			"timestamp_ms": Time.get_ticks_msec(),
		}
		for key in PROFILE_MONITORS.keys():
			var monitor = PROFILE_MONITORS[key]
			var value = Performance.get_monitor(monitor)
			if key.ends_with("_ms"):
				monitor_sample[key] = float(value) * 1000.0
			else:
				monitor_sample[key] = float(value)
		monitor_samples.append(monitor_sample)

		if batcher and batcher.has_method("get_performance_metrics"):
			batcher_samples.append(batcher.get_performance_metrics())

	var render_breakdown := {}
	if quantum_viz and quantum_viz.has_method("get_performance_breakdown"):
		render_breakdown = quantum_viz.get_performance_breakdown()

	var batcher_summary := _summarize_batcher_samples(batcher_samples)
	var monitor_summary := _summarize_monitor_samples(monitor_samples)
	var runtime_dormant: bool = batcher.has_method("is_runtime_dormant") and batcher.is_runtime_dormant() if batcher else false
	var rendering_device = RenderingServer.get_rendering_device()

	return {
		"mode": _profile_mode,
		"description": scenario.get("description", ""),
		"display": DisplayServer.get_name(),
		"video_adapter_name": RenderingServer.get_video_adapter_name(),
		"rendering_device_available": rendering_device != null,
		"cmdline_args": OS.get_cmdline_args(),
		"sample_frames": _sample_frames,
		"warmup_frames": _warmup_frames,
		"scenario": scenario,
		"runtime_dormant": runtime_dormant,
		"monitor_summary": monitor_summary,
		"render_breakdown": render_breakdown,
		"batcher_summary": batcher_summary,
		"monitor_samples": monitor_samples,
		"batcher_samples": batcher_samples,
	}


func _summarize_monitor_samples(samples: Array) -> Dictionary:
	var summary := {}
	if samples.is_empty():
		return summary

	for key in PROFILE_MONITORS.keys():
		var values := []
		for sample in samples:
			values.append(float(sample.get(key, 0.0)))
		summary[key] = _summarize_numeric_values(values)

	return summary


func _summarize_batcher_samples(samples: Array) -> Dictionary:
	var summary := {}
	if samples.is_empty():
		return summary

	var numeric_keys := [
		"last_batch_time_ms",
		"avg_batch_time_ms",
		"avg_frame_time_ms",
		"biomes_active",
		"biomes_paused",
		"buffer_depth",
		"buffer_coverage_ms",
		"packets_pending",
		"packet_started_ms_ago",
		"packet_completed_ms_ago",
	]
	for key in numeric_keys:
		var values := []
		for sample in samples:
			if sample.has(key):
				values.append(float(sample.get(key, 0.0)))
		if not values.is_empty():
			summary[key] = _summarize_numeric_values(values)

	var bool_keys := ["active_packet", "emergency_refill"]
	for key in bool_keys:
		var true_count := 0
		for sample in samples:
			if bool(sample.get(key, false)):
				true_count += 1
		summary[key] = {
			"true_ratio": float(true_count) / samples.size(),
			"true_count": true_count,
			"samples": samples.size(),
		}

	if not samples.is_empty():
		summary["latest"] = samples[-1]

	return summary


func _summarize_numeric_values(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:
		total += float(value)
	var avg := total / ordered.size()
	var mid := ordered.size() / 2
	var median := float(ordered[mid])
	var p95_idx: int = min(ordered.size() - 1, int(ordered.size() * 0.95))
	return {
		"avg": avg,
		"median": median,
		"min": float(ordered[0]),
		"max": float(ordered[-1]),
		"p95": float(ordered[p95_idx]),
	}


func _write_report(report: Dictionary) -> void:
	var output_path := _output_path
	if output_path == "":
		output_path = "/tmp/spacewheat_runtime_profile_%s.json" % _profile_mode
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("failed to open profile output: %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("profile report written: %s" % output_path)


func _print_report_summary(report: Dictionary) -> void:
	var monitor_summary: Dictionary = report.get("monitor_summary", {})
	var render: Dictionary = report.get("render_breakdown", {})
	var batcher_summary: Dictionary = report.get("batcher_summary", {})
	print("")
	print("PROFILE SUMMARY [%s]" % report.get("mode", "unknown"))
	print("  scenario: %s" % report.get("description", ""))
	print("  display: %s" % report.get("display", "unknown"))
	print("  adapter: %s" % report.get("video_adapter_name", "unknown"))
	print("  rendering device: %s" % str(report.get("rendering_device_available", false)))
	print("  fps avg: %.2f" % _summary_value(monitor_summary, "fps", "avg"))
	print("  process avg: %.2fms" % _summary_value(monitor_summary, "time_process_ms", "avg"))
	print("  physics avg: %.2fms" % _summary_value(monitor_summary, "time_physics_ms", "avg"))
	print("  render process avg: %.2fms" % float(render.get("avg_ms", {}).get("process_total", 0.0)))
	print("  render draw avg: %.2fms" % float(render.get("avg_ms", {}).get("draw_total", 0.0)))
	print("  render untracked avg: %.2fms" % float(render.get("untracked_ms", 0.0)))
	print("  batch avg: %.2fms" % _summary_value(batcher_summary, "avg_batch_time_ms", "avg"))
	print("  active biomes avg: %.2f" % _summary_value(batcher_summary, "biomes_active", "avg"))
	print("  packets pending avg: %.2f" % _summary_value(batcher_summary, "packets_pending", "avg"))
	print("  runtime dormant: %s" % str(report.get("runtime_dormant", false)))


func _summary_value(summary: Dictionary, key: String, field: String) -> float:
	var entry = summary.get(key, {})
	if entry is Dictionary:
		return float(entry.get(field, 0.0))
	return 0.0


func _resolve_biome_name(farm) -> String:
	var names := _resolve_biome_names(farm, 1)
	return str(names[0]) if not names.is_empty() else ""


func _resolve_biome_names(farm, count: int) -> Array:
	var names: Array = []
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("get_active_biome"):
		var active = str(abm.get_active_biome())
		if active != "":
			names.append(active)

	if farm and farm.grid:
		for biome_name in farm.grid.get_biome_names():
			var bname := str(biome_name)
			if names.has(bname):
				continue
			names.append(bname)
			if names.size() >= count:
				break

	return names.slice(0, min(count, names.size()))


func _resolve_plot_position(farm, biome_name: String) -> Vector2i:
	var positions := _resolve_plot_positions(farm, biome_name, 1)
	return positions[0] if not positions.is_empty() else GridSentinel.INVALID_POSITION


func _resolve_plot_positions(farm, biome_name: String, count: int) -> Array:
	if not farm or not farm.grid:
		return []
	var resolved := []
	var positions = farm.grid.get_plot_positions_for_biome(biome_name)
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot and (not plot.is_active() or not plot.terminal):
			resolved.append(pos)
		if resolved.size() >= count:
			break
	return resolved


func _wait_for_bubble(quantum_viz, plot_pos: Vector2i) -> bool:
	for _i in range(180):
		if quantum_viz and quantum_viz.quantum_nodes_by_grid_pos.has(plot_pos):
			return true
		await process_frame
	return false
