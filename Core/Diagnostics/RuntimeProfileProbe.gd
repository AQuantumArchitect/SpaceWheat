class_name RuntimeProfileProbe
extends Node

const GridSentinel = preload("res://Core/GameState/GridSentinel.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

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
const DEFAULT_EXPANDED_BIOMES := 4
const DEFAULT_EXPANDED_TERMINALS_PER_BIOME := 2

var farm = null
var quantum_viz = null
var _mode := ""
var _output_path := ""
var _warmup_frames := DEFAULT_WARMUP_FRAMES
var _sample_frames := DEFAULT_SAMPLE_FRAMES
var _dense_terminals := DEFAULT_DENSE_TERMINALS
var _multi_biomes := DEFAULT_MULTI_BIOMES
var _expanded_biomes := DEFAULT_EXPANDED_BIOMES
var _expanded_terminals_per_biome := DEFAULT_EXPANDED_TERMINALS_PER_BIOME


static func should_run_from_runtime_args() -> bool:
	return _runtime_profile_arg_map().get("runtime-profile-mode", "") != "" \
		or OS.get_environment("SW_RUNTIME_PROFILE_MODE").strip_edges() != ""


func configure(profile_farm, profile_quantum_viz) -> void:
	farm = profile_farm
	quantum_viz = profile_quantum_viz
	var cfg := _runtime_profile_config()
	_mode = str(cfg.get("mode", "single"))
	_output_path = str(cfg.get("output_path", ""))
	_warmup_frames = int(cfg.get("warmup_frames", DEFAULT_WARMUP_FRAMES))
	_sample_frames = int(cfg.get("sample_frames", DEFAULT_SAMPLE_FRAMES))
	_dense_terminals = int(cfg.get("dense_terminals", DEFAULT_DENSE_TERMINALS))
	_multi_biomes = int(cfg.get("multi_biomes", DEFAULT_MULTI_BIOMES))
	_expanded_biomes = int(cfg.get("expanded_biomes", DEFAULT_EXPANDED_BIOMES))
	_expanded_terminals_per_biome = int(cfg.get("expanded_terminals_per_biome", DEFAULT_EXPANDED_TERMINALS_PER_BIOME))


func start() -> void:
	call_deferred("_run")


static func _runtime_profile_arg_map() -> Dictionary:
	var mapping := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var trimmed = arg.substr(2)
		var parts = trimmed.split("=", false, 1)
		if parts.is_empty():
			continue
		var key = String(parts[0]).strip_edges().to_lower()
		var value = "true"
		if parts.size() > 1:
			value = String(parts[1]).strip_edges()
		mapping[key] = value
	return mapping


static func _runtime_profile_config() -> Dictionary:
	var args := _runtime_profile_arg_map()
	return {
		"mode": _string_setting(args, "runtime-profile-mode", "SW_RUNTIME_PROFILE_MODE", "single").to_lower(),
		"output_path": _string_setting(args, "runtime-profile-output", "SW_RUNTIME_PROFILE_OUTPUT", ""),
		"warmup_frames": _int_setting(args, "runtime-profile-warmup", "SW_RUNTIME_PROFILE_WARMUP", DEFAULT_WARMUP_FRAMES),
		"sample_frames": _int_setting(args, "runtime-profile-frames", "SW_RUNTIME_PROFILE_FRAMES", DEFAULT_SAMPLE_FRAMES),
		"dense_terminals": _int_setting(args, "runtime-profile-dense-terminals", "SW_RUNTIME_PROFILE_DENSE_TERMINALS", DEFAULT_DENSE_TERMINALS),
		"multi_biomes": _int_setting(args, "runtime-profile-multi-biomes", "SW_RUNTIME_PROFILE_MULTI_BIOMES", DEFAULT_MULTI_BIOMES),
		"expanded_biomes": _int_setting(args, "runtime-profile-expanded-biomes", "SW_RUNTIME_PROFILE_EXPANDED_BIOMES", DEFAULT_EXPANDED_BIOMES),
		"expanded_terminals_per_biome": _int_setting(args, "runtime-profile-expanded-terminals-per-biome", "SW_RUNTIME_PROFILE_EXPANDED_TERMINALS_PER_BIOME", DEFAULT_EXPANDED_TERMINALS_PER_BIOME),
	}


static func _string_setting(args: Dictionary, arg_key: String, env_key: String, default_value: String) -> String:
	if args.has(arg_key):
		return String(args[arg_key]).strip_edges()
	var raw = OS.get_environment(env_key).strip_edges()
	return raw if raw != "" else default_value


static func _int_setting(args: Dictionary, arg_key: String, env_key: String, default_value: int) -> int:
	var raw = _string_setting(args, arg_key, env_key, "")
	return int(raw) if raw != "" and raw.is_valid_int() else default_value


func _run() -> void:
	if farm == null:
		printerr("runtime profile probe missing farm")
		get_tree().quit(10)
		return

	var instrument = await _wait_for_instrument()
	if instrument == null:
		printerr("runtime profile probe instrument timeout")
		get_tree().quit(11)
		return

	var scenario := await _apply_profile_mode(instrument)
	if not scenario.get("ok", false):
		printerr("runtime profile setup failed: %s" % scenario.get("error", "unknown"))
		get_tree().quit(12)
		return

	for _i in range(_warmup_frames):
		await get_tree().process_frame

	var report := await _capture_profile_report(scenario)
	_write_report(report)
	_print_report_summary(report)

	get_tree().quit(0)


func _wait_for_instrument() -> Object:
	for _i in range(240):
		if farm and farm.instrument:
			return farm.instrument
		await get_tree().process_frame
	return null


func _apply_profile_mode(instrument) -> Dictionary:
	match _mode:
		"dormant":
			return {
				"ok": true,
				"mode": _mode,
				"explored": [],
				"description": "booted runtime with no explored terminals",
			}
		"single":
			var single_biome := _resolve_biome_name()
			if single_biome == "":
				return {"ok": false, "error": "no_biome"}
			var single_pos := _resolve_plot_position(single_biome)
			if single_pos == GridSentinel.INVALID_POSITION:
				return {"ok": false, "error": "no_plot"}
			var one = await _explore_positions(instrument, [{"biome": single_biome, "pos": single_pos}])
			one["description"] = "one active biome with one bound terminal"
			return one
		"dense":
			var dense_biome := _resolve_biome_name()
			if dense_biome == "":
				return {"ok": false, "error": "no_biome"}
			var dense_targets := []
			for pos in _resolve_plot_positions(dense_biome, _dense_terminals):
				dense_targets.append({"biome": dense_biome, "pos": pos})
			if dense_targets.is_empty():
				return {"ok": false, "error": "no_dense_targets"}
			var dense = await _explore_positions(instrument, dense_targets)
			dense["description"] = "one active biome with %d bound terminals" % dense_targets.size()
			return dense
		"multi":
			var multi_targets := []
			for biome_name in _resolve_biome_names(_multi_biomes):
				var pos := _resolve_plot_position(biome_name)
				if pos != GridSentinel.INVALID_POSITION:
					multi_targets.append({"biome": biome_name, "pos": pos})
			if multi_targets.is_empty():
				return {"ok": false, "error": "no_multi_targets"}
			var multi = await _explore_positions(instrument, multi_targets)
			multi["description"] = "%d active biomes with one bound terminal each" % multi_targets.size()
			return multi
		"expanded":
			return await _apply_expanded_profile()
		_:
			return {"ok": false, "error": "unknown_mode_%s" % _mode}


func _explore_positions(instrument, targets: Array) -> Dictionary:
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
				"message": result.get("message", "unknown"),
			}
		if not await _wait_for_bubble(pos):
			return {"ok": false, "error": "bubble_timeout_%s_%s" % [biome_name, str(pos)]}
		explored.append({
			"biome": biome_name,
			"grid_pos": {"x": pos.x, "y": pos.y},
		})

	return {
		"ok": true,
		"mode": _mode,
		"explored": explored,
	}


func _apply_expanded_profile() -> Dictionary:
	var loaded_names := await _ensure_profile_biomes_loaded(_expanded_biomes)
	if loaded_names.is_empty():
		return {"ok": false, "error": "no_expanded_biomes_loaded"}

	var needed_terminals := loaded_names.size() * _expanded_terminals_per_biome
	if farm and "terminal_pool" in farm and farm.terminal_pool and farm.terminal_pool.has_method("resize"):
		if "pool_size" in farm.terminal_pool and farm.terminal_pool.pool_size < needed_terminals:
			farm.terminal_pool.resize(needed_terminals)

	var explored := []
	for biome_name in loaded_names:
		var count := 0
		for pos in _resolve_plot_positions(biome_name, _expanded_terminals_per_biome):
			var result := _profile_bind_terminal_without_cost(biome_name, pos)
			if not result.get("success", false):
				return {
					"ok": false,
					"error": "expanded_bind_failed_%s_%s" % [biome_name, str(pos)],
					"message": result.get("message", "unknown"),
				}
			if not await _wait_for_bubble(pos):
				return {"ok": false, "error": "expanded_bubble_timeout_%s_%s" % [biome_name, str(pos)]}
			explored.append({"biome": biome_name, "grid_pos": {"x": pos.x, "y": pos.y}})
			count += 1
			if count >= _expanded_terminals_per_biome:
				break

	return {
		"ok": true,
		"mode": _mode,
		"explored": explored,
		"description": "%d loaded biomes with up to %d bound terminals each" % [loaded_names.size(), _expanded_terminals_per_biome],
	}


func _ensure_profile_biomes_loaded(count: int) -> Array:
	var names := _resolve_loadable_biome_names(count)
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	for biome_name in names:
		if observation_frame and observation_frame.has_method("unlock_biome") and biome_name not in observation_frame.get_unlocked_biomes():
			observation_frame.unlock_biome(biome_name)
	if farm and farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()

	for biome_name in names:
		if farm and farm.has_method("_load_biome_dynamically"):
			farm._load_biome_dynamically(biome_name)
		await get_tree().process_frame

	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("set_biome_order") and observation_frame:
		abm.set_biome_order(observation_frame.get_unlocked_biomes())

	var loaded := []
	for biome_name in names:
		if farm and farm.grid and farm.grid.get_biome(biome_name):
			loaded.append(biome_name)
	return loaded


func _resolve_loadable_biome_names(count: int) -> Array:
	var names: Array = []
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if observation_frame and observation_frame.has_method("get_loadable_biomes"):
		for biome_name in observation_frame.get_loadable_biomes():
			var bname := str(biome_name)
			if bname != "" and bname not in names:
				names.append(bname)
			if names.size() >= count:
				break
	if names.is_empty():
		names = _resolve_biome_names(count)
	return names.slice(0, min(count, names.size()))


func _profile_bind_terminal_without_cost(biome_name: String, pos: Vector2i) -> Dictionary:
	if not farm or not farm.grid or not farm.terminal_pool:
		return {"success": false, "error": "profile_farm_not_ready"}
	var biome = farm.grid.get_biome(biome_name)
	if not biome:
		return {"success": false, "error": "profile_biome_not_loaded"}
	var result := ProbeActions.action_explore(farm.terminal_pool, biome, null)
	if result.get("success", false):
		var terminal = result.get("terminal", null)
		if terminal:
			terminal.grid_position = pos
		if farm.has_method("emit_action_signal"):
			farm.emit_action_signal("explore", result, pos)
	return result


func _wait_for_bubble(pos: Vector2i) -> bool:
	if quantum_viz == null:
		return true
	for _i in range(240):
		if _quantum_viz_has_bubble(pos):
			return true
		await get_tree().process_frame
	return false


func _quantum_viz_has_bubble(pos: Vector2i) -> bool:
	if quantum_viz == null:
		return false
	if quantum_viz.has_method("has_quantum_node_at") and quantum_viz.has_quantum_node_at(pos):
		return true
	if "quantum_nodes_by_grid_pos" in quantum_viz and quantum_viz.quantum_nodes_by_grid_pos.has(pos):
		return true
	if quantum_viz.has_method("get_performance_breakdown"):
		var breakdown: Dictionary = quantum_viz.get_performance_breakdown()
		if int(breakdown.get("active_node_count", 0)) > 0:
			return true
	return false


func _capture_profile_report(scenario: Dictionary) -> Dictionary:
	if quantum_viz and quantum_viz.has_method("reset_performance_breakdown"):
		quantum_viz.reset_performance_breakdown()
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher and batcher.has_method("reset_performance_metrics"):
		batcher.reset_performance_metrics()

	var monitor_samples := []
	var batcher_samples := []
	var previous_sample_us := Time.get_ticks_usec()

	for frame_idx in range(_sample_frames):
		await get_tree().process_frame
		var sample_time_ms := Time.get_ticks_msec()
		var sample_time_us := Time.get_ticks_usec()
		var monitor_sample := {
			"frame": frame_idx + 1,
			"timestamp_ms": sample_time_ms,
			"wall_frame_delta_ms": float(sample_time_us - previous_sample_us) / 1000.0,
		}
		previous_sample_us = sample_time_us
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

	var monitor_summary := _summarize_monitor_samples(monitor_samples)
	var batcher_summary := _summarize_batcher_samples(batcher_samples)
	var rendering_device = RenderingServer.get_rendering_device()

	return {
		"profile_source": "runtime_probe",
		"mode": _mode,
		"description": scenario.get("description", ""),
		"display": DisplayServer.get_name(),
		"video_adapter_name": RenderingServer.get_video_adapter_name(),
		"video_adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"video_adapter_type": int(RenderingServer.get_video_adapter_type()),
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"rendering_device_available": rendering_device != null,
		"visualization_active": quantum_viz != null,
		"cmdline_args": OS.get_cmdline_args(),
		"cmdline_user_args": OS.get_cmdline_user_args(),
		"sample_frames": _sample_frames,
		"warmup_frames": _warmup_frames,
		"scenario": scenario,
		"runtime_dormant": batcher.has_method("is_runtime_dormant") and batcher.is_runtime_dormant() if batcher else false,
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
		"physics_fps",
		"slices_consumed_per_second",
		"biomes_active",
		"biomes_paused",
		"active_biome_count",
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

	for key in ["active_packet", "emergency_refill"]:
		var true_count := 0
		for sample in samples:
			if bool(sample.get(key, false)):
				true_count += 1
		summary[key] = {
			"true_ratio": float(true_count) / samples.size(),
			"true_count": true_count,
			"samples": samples.size(),
		}

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
	var p95_idx: int = min(ordered.size() - 1, int(ordered.size() * 0.95))
	return {
		"avg": avg,
		"median": float(ordered[mid]),
		"min": float(ordered[0]),
		"max": float(ordered[-1]),
		"p95": float(ordered[p95_idx]),
	}


func _write_report(report: Dictionary) -> void:
	var output_path := _output_path
	if output_path == "":
		output_path = "user://runtime_profile_%s.json" % _mode
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("failed to open runtime profile output: %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("runtime profile report written: %s" % output_path)


func _print_report_summary(report: Dictionary) -> void:
	var monitor_summary: Dictionary = report.get("monitor_summary", {})
	var render: Dictionary = report.get("render_breakdown", {})
	var batcher_summary: Dictionary = report.get("batcher_summary", {})
	print("")
	print("RUNTIME PROFILE SUMMARY [%s]" % report.get("mode", "unknown"))
	print("  scenario: %s" % report.get("description", ""))
	print("  display: %s" % report.get("display", "unknown"))
	print("  adapter: %s" % report.get("video_adapter_name", "unknown"))
	print("  vendor: %s" % report.get("video_adapter_vendor", "unknown"))
	print("  api: %s" % report.get("video_adapter_api_version", "unknown"))
	print("  rendering device: %s" % str(report.get("rendering_device_available", false)))
	print("  fps avg: %.2f" % _summary_value(monitor_summary, "fps", "avg"))
	print("  process avg: %.2fms" % _summary_value(monitor_summary, "time_process_ms", "avg"))
	print("  physics avg: %.2fms" % _summary_value(monitor_summary, "time_physics_ms", "avg"))
	print("  render process avg: %.2fms" % float(render.get("avg_ms", {}).get("process_total", 0.0)))
	print("  render draw avg: %.2fms" % float(render.get("avg_ms", {}).get("draw_total", 0.0)))
	print("  render untracked avg: %.2fms" % float(render.get("untracked_ms", 0.0)))
	print("  batch avg: %.2fms" % _summary_value(batcher_summary, "avg_batch_time_ms", "avg"))
	print("  PhHz avg: %.2f" % _summary_value(batcher_summary, "physics_fps", "avg"))
	print("  evol slices/s avg: %.2f" % _summary_value(batcher_summary, "slices_consumed_per_second", "avg"))
	print("  active biomes avg: %.2f" % _summary_value(batcher_summary, "biomes_active", "avg"))
	print("  packets pending avg: %.2f" % _summary_value(batcher_summary, "packets_pending", "avg"))
	print("  runtime dormant: %s" % str(report.get("runtime_dormant", false)))


func _summary_value(summary: Dictionary, key: String, field: String) -> float:
	var entry = summary.get(key, {})
	return float(entry.get(field, 0.0)) if entry is Dictionary else 0.0


func _resolve_biome_name() -> String:
	var names := _resolve_biome_names(1)
	return str(names[0]) if not names.is_empty() else ""


func _resolve_biome_names(count: int) -> Array:
	var names: Array = []
	var abm = get_node_or_null("/root/ActiveBiomeManager")
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


func _resolve_plot_position(biome_name: String) -> Vector2i:
	var positions := _resolve_plot_positions(biome_name, 1)
	return positions[0] if not positions.is_empty() else GridSentinel.INVALID_POSITION


func _resolve_plot_positions(biome_name: String, count: int) -> Array:
	if not farm or not farm.grid:
		return []
	var resolved := []
	for pos in farm.grid.get_plot_positions_for_biome(biome_name):
		var plot = farm.grid.get_plot(pos)
		if plot and (not plot.is_active() or not plot.terminal):
			resolved.append(pos)
		if resolved.size() >= count:
			break
	return resolved
