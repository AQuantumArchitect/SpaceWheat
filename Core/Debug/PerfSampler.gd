extends Node

## Machine-readable performance sampler — the ONE way to get frame numbers out of
## a SHIPPED build without reading them off a screenshot.
##
## Why this exists. Until now the only perf channels in a release build were both
## on-screen: FpsDisplay's strip (RuntimeEnv.debug_readout_enabled) and the Z ›
## dev tab. Everything machine-readable lived in `tests/`, which every export
## preset excludes — so `scripts/profile-export-runtime.sh` passed
## `--runtime-profile-mode=…` to an exported binary that had no parser for it,
## and then warned that no JSON appeared. A profiling lane that addresses a
## parser which isn't in the build is worse than no lane: it reports absence of
## data as a build problem.
##
## What it does. Set SW_PERF_LOG=<path> and the game samples every frame, writes
## one JSON report, and (with SW_PERF_SECONDS) quits on its own — so an agent can
## launch the exe, wait, and read numbers, with no window-scraping and no rig.
## The rig is not an option here: `🍄/**` is excluded from every export, so the
## shipped game a player runs has no listener in it. This does.
##
## Unset SW_PERF_LOG and _ready() disables processing on the first frame. A
## player's build pays one env read at boot and nothing after.
##
## THE HONESTY FIELD. `environment.software_rendering_suspected` is the desktop
## twin of the web smoke's `webgl_renderer`. A frame rate without its renderer is
## an adjective: this project has already published one fps number measured on
## SwiftShader and one on llvmpipe, neither of which can judge a floor. The
## report always names the adapter, and says plainly when that adapter cannot
## support a verdict — so a wrong number has to be read past, not stumbled into.

# "Is this a software rasteriser?" already has an owner: PerformanceOptimizer,
# which uses the answer to decide the frame cap. A second list here would be a
# second authority that could drift, and the drift would be invisible — the game
# would cap for software while the report called the run trustworthy.
const PerfOptimizer = preload("res://Core/Settings/PerformanceOptimizer.gd")

var _log_path: String = ""
var _warmup_s: float = 0.0
var _duration_s: float = 0.0
var _quit_when_done: bool = true
var _snapshot_interval_s: float = 1.0

var _elapsed: float = 0.0
# Wall clock, deliberately NOT accumulated `_process` delta. Godot multiplies
# that delta by Engine.time_scale, and FloatingRewardLayer dips time_scale to
# 0.06 for every big pop — so a run full of celebrations measured its own window
# and every frame in it in DILATED seconds. Measured 2026-08-13: a headless
# endgame run took 280.7s of wall clock and reported 32.4s, an 8.7x understatement
# that made a per-frame stall look eight times smaller than the player feels it,
# and made "share of the window" arithmetic exceed 100%.
var _wall_start_us: int = 0
var _last_frame_us: int = 0
var _time_scale_min: float = 1.0
var _time_scale_sum: float = 0.0
var _time_scale_samples: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _warmup_frame_ms: PackedFloat64Array = PackedFloat64Array()
var _snapshots: Array[Dictionary] = []
var _next_snapshot_at: float = 0.0
var _written: bool = false
var _engine_process_ms_total: float = 0.0
var _engine_physics_ms_total: float = 0.0
var _hitches: Array[Dictionary] = []
var _ledger_prev: Dictionary = {}
const _MAX_HITCH_LOG := 64

# 4 hours at 240fps. A cap only a runaway session reaches; recorded in the report
# when it bites, because a silently truncated sample is a lie about the window.
const _MAX_SAMPLES := 3_456_000
var _dropped_samples: int = 0


func _ready() -> void:
	_log_path = RuntimeEnv.perf_log_path()
	if _log_path == "":
		set_process(false)
		return

	_warmup_s = RuntimeEnv.perf_warmup_seconds()
	_duration_s = RuntimeEnv.perf_duration_seconds()
	_quit_when_done = RuntimeEnv.perf_quit_when_done()
	_snapshot_interval_s = maxf(0.1, RuntimeEnv.perf_snapshot_interval_seconds())
	_next_snapshot_at = _warmup_s

	_wall_start_us = Time.get_ticks_usec()
	_last_frame_us = _wall_start_us

	# Tagged hitch logs go through VerboseConfig.perf. Raise it to DEBUG so the
	# 1 Hz heartbeat prints; WARN (the default) still catches stalls. Do NOT
	# flip the whole logger to TRACE — that would eat the fps we are measuring.
	var vc = get_node_or_null("/root/VerboseConfig")
	if vc:
		if vc.has_method("set_category_enabled"):
			vc.set_category_enabled("perf", true)
		if vc.has_method("set_category_level"):
			vc.set_category_level("perf", vc.LogLevel.DEBUG)

	# Sample after every other _process in the frame, so a snapshot reflects the
	# work the frame actually did rather than half of it.
	process_priority = 1000
	get_window().close_requested.connect(_on_close_requested)

	print("[PERF] sampling → %s (warmup %.1fs, duration %s, quit_when_done %s)" % [
		_log_path, _warmup_s,
		("%.1fs" % _duration_s) if _duration_s > 0.0 else "until quit",
		str(_quit_when_done)])


func _process(_delta: float) -> void:
	# `_delta` is ignored on purpose — see _wall_start_us. Every number this
	# sampler reports is in real seconds a player would count on a stopwatch.
	var now_us := Time.get_ticks_usec()
	var ms := float(now_us - _last_frame_us) / 1000.0
	_last_frame_us = now_us
	_elapsed = float(now_us - _wall_start_us) / 1_000_000.0

	var ts := Engine.time_scale
	_time_scale_min = minf(_time_scale_min, ts)
	_time_scale_sum += ts
	_time_scale_samples += 1

	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	# TIME_PROCESS is last-completed-frame and goes STALE across short frames
	# after a hitch (measured 2026-08-15: 113ms stuck on 38ms/46ms/84ms walls).
	# Never attribute more process than this wall slice; if the monitor is
	# clearly leftover from a previous hitch, count the slice as present-wait
	# (vsync / GPU / the hole after a stall), not as engine work.
	if _elapsed >= _warmup_s:
		if process_ms <= ms * 1.25:
			_engine_process_ms_total += minf(process_ms, ms)
			_engine_physics_ms_total += minf(physics_ms, ms)
		else:
			# stale — do not add process_ms; the wall still happened
			pass

	if _elapsed < _warmup_s:
		# Kept, not discarded: boot cost is a real number a player pays, it just
		# is not the steady state the floor is about. Reported separately.
		_warmup_frame_ms.append(ms)
		# Seed so the first steady-state hitch is a frame delta, not the
		# entire warmup dump (first hitch at t=warmup used to name 1.2 s of
		# farm_physics_rest as if it ran on that frame).
		_ledger_prev = FrameCostLedger.totals()
	elif _frame_ms.size() < _MAX_SAMPLES:
		_frame_ms.append(ms)
		if ms > 33.4:
			_record_hitch(ms, process_ms, physics_ms)
		_ledger_prev = FrameCostLedger.totals()
	else:
		_dropped_samples += 1

	if _elapsed >= _next_snapshot_at:
		_next_snapshot_at = _elapsed + _snapshot_interval_s
		var snap := _take_snapshot()
		_snapshots.append(snap)
		_log_heartbeat(snap, ms)

	if _duration_s > 0.0 and _elapsed >= _warmup_s + _duration_s:
		_finish("duration_reached")


func _record_hitch(ms: float, process_ms: float, physics_ms: float) -> void:
	var viz: Dictionary = FrameCostLedger.totals()
	var ledger_ms := {}
	for key in viz.keys():
		var d := float(viz[key]) - float(_ledger_prev.get(key, 0.0))
		if d > 0.05:
			ledger_ms[key] = snappedf(d, 0.01)
	var detail := {
		"process_ms": snappedf(process_ms, 0.1),
		"physics_ms": snappedf(physics_ms, 0.1),
		"present_wait_ms": snappedf(maxf(0.0, ms - process_ms), 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"ledger_ms": ledger_ms,
	}
	if viz.has("viz_field3d"):
		detail["field3d_ms_cum"] = snappedf(float(viz["viz_field3d"]), 0.1)
	var vc = get_node_or_null("/root/VerboseConfig")
	if vc and vc.has_method("hitch"):
		vc.hitch("frame", ms, detail)
	if _hitches.size() < _MAX_HITCH_LOG:
		detail["t"] = snappedf(_elapsed, 0.01)
		detail["wall_ms"] = snappedf(ms, 0.1)
		_hitches.append(detail)


func _log_heartbeat(snap: Dictionary, ms: float) -> void:
	var vc = get_node_or_null("/root/VerboseConfig")
	if vc == null or not vc.has_method("debug"):
		return
	var b: Dictionary = snap.get("batcher", {})
	vc.debug("perf", "💓", "t=%.1fs fps=%s wall=%.1fms proc=%.1f phys=%.1f draws=%s buf=%s" % [
		_elapsed,
		str(snap.get("fps", "?")),
		ms,
		float(snap.get("process_ms", 0.0)),
		float(snap.get("physics_process_ms", 0.0)),
		str(snap.get("draw_calls", "?")),
		str(b.get("buffer_state", "-")),
	])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_finish("shutdown")


func _on_close_requested() -> void:
	_finish("window_closed")


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

func _take_snapshot() -> Dictionary:
	var snap := {
		"t": _elapsed,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1_048_576.0,
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1_048_576.0,
		"engine_process_ms_total": _engine_process_ms_total,
		"engine_physics_ms_total": _engine_physics_ms_total,
	}
	var batcher := _resolve_batcher()
	var viz: Dictionary = FrameCostLedger.totals()
	if not viz.is_empty():
		snap["viz"] = viz
	if batcher != null:
		var m: Dictionary = batcher.get_performance_metrics()
		# The physics side of the frame: SpaceWheat's cost is not all rendering,
		# and a report that only names fps cannot tell those two apart.
		snap["batcher"] = {
			"avg_batch_time_ms": m.get("avg_batch_time_ms", null),
			"avg_frame_time_ms": m.get("avg_frame_time_ms", null),
			"buffer_state": m.get("buffer_state", null),
			"biomes_active": m.get("biomes_active", null),
			"biomes_paused": m.get("biomes_paused", null),
			"packets_pending": m.get("packets_pending", null),
			"watchdog_stall_warnings": m.get("watchdog_stall_warnings", null),
			"phrame_cap_hz": m.get("phrame_cap_hz", null),
			# Cumulative — two snapshots give the FRACTION of wall time inside the
			# native call and inside the GDScript merge that unpacks it. An average
			# per-packet cost cannot say that, and reading it as though it could is
			# what sent the first pass at #528 after the wrong half of the frame.
			"native_ms_total": m.get("native_ms_total", null),
			"merge_ms_total": m.get("merge_ms_total", null),
			"take_ms_total": m.get("take_ms_total", null),
			"consume_ms_total": m.get("consume_ms_total", null),
			"refill_ms_total": m.get("refill_ms_total", null),
			"poll_ms_total": m.get("poll_ms_total", null),
			"packets_total": m.get("packets_total", null),
			# Per-STEP, so two builds stay comparable when adaptive sizing moves
			# the packet under them. Per-packet cost alone cannot do that.
			"native_ms_per_step": m.get("native_ms_per_step", null),
			"steps_total": m.get("steps_total", null),
		}
	return snap


# Object, not Node: BiomeEvolutionBatcher is a RefCounted owned by the farm, not
# a scene-tree child. Typing this `Node` compiled fine and threw once per second
# at runtime — which is why the sampler was booted for real before it shipped.
func _resolve_batcher() -> Object:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not ("biome_evolution_batcher" in farm):
		return null
	var batcher = farm.biome_evolution_batcher
	if batcher == null or not batcher.has_method("get_performance_metrics"):
		return null
	return batcher


# ---------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------

func _finish(reason: String) -> void:
	if _written or _log_path == "":
		return
	_written = true
	set_process(false)

	var report := _build_report(reason)
	var err: Error = OK
	if _log_path.begins_with("web://"):
		err = await _post_web_report(report)
	else:
		err = _write_json(_log_path, report)
	if err != OK:
		printerr("[PERF] could not write %s (error %d)" % [_log_path, err])
	else:
		print("[PERF] wrote %s — %d frames, %s" % [
			_log_path, _frame_ms.size(), _verdict_line(report)])

	if _quit_when_done and reason == "duration_reached":
		get_tree().quit(0)


func _build_report(reason: String) -> Dictionary:
	var env := _environment()
	return {
		"schema": "spacewheat.perf/1",
		"stop_reason": reason,
		"build": {
			"display": BuildInfo.display(),
			"version": BuildInfo.version(),
			"stamp": BuildInfo.stamp(),
			"is_stamped": BuildInfo.is_stamped(),
			"is_debug_build": OS.is_debug_build(),
		},
		"environment": env,
		"runtime_env": RuntimeEnv.describe(),
		"window": {
			"warmup_seconds": _warmup_s,
			"measured_seconds": maxf(0.0, _elapsed - _warmup_s),
			"total_seconds": _elapsed,
			"snapshot_interval_seconds": _snapshot_interval_s,
			"dropped_samples": _dropped_samples,
			# Named so a reader can tell a dilated run from a slow one. Both look
			# like "low fps"; only one of them is the game being slow.
			"clock": "wall",
			"engine_time_scale_min": _time_scale_min,
			"engine_time_scale_mean": (_time_scale_sum / float(_time_scale_samples)) if _time_scale_samples > 0 else 1.0,
		},
		"steady_state": _stats(_frame_ms),
		"warmup": _stats(_warmup_frame_ms),
		"attribution": _attribution(),
		"hitches": _hitches,
		"snapshots": _snapshots,
		# The caller should not have to know which fields invalidate a run.
		"trustworthy": not bool(env.get("software_rendering_suspected", true)),
		"caveats": _caveats(env),
	}


func _environment() -> Dictionary:
	var adapter := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	# A headless run draws nothing; its fps is a CPU number wearing a render
	# label, which is exactly the confusion this field exists to prevent.
	var software: bool = RuntimeEnv.is_headless() or PerfOptimizer.detect_software_renderer()
	# A virtual display (Xvfb, common on cloud build agents) reports no refresh
	# rate — NAN. Godot's JSON.stringify emits that as the bare token `nan`,
	# which is not valid JSON (and doesn't even match Python's `NaN` spelling),
	# so any report cut under a virtual display failed to parse afterward. null
	# says "unknown" instead of poisoning the file.
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	var refresh_rate_json = null if is_nan(refresh_rate) else refresh_rate

	return {
		"os": OS.get_name(),
		"distribution": OS.get_distribution_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"video_adapter": adapter,
		"video_adapter_vendor": vendor,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter_type": RenderingServer.get_video_adapter_type(),
		"rendering_driver": ProjectSettings.get_setting("rendering/rendering_device/driver", ""),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"display_server": DisplayServer.get_name(),
		"headless": RuntimeEnv.is_headless(),
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"screen_refresh_rate": refresh_rate_json,
		"max_fps": Engine.max_fps,
		"software_rendering_suspected": software,
	}


func _caveats(env: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var headless := bool(env.get("headless", false))
	if headless:
		out.append("headless run — nothing was rendered; fps here is not a frame rate a player would see")
	elif bool(env.get("software_rendering_suspected", false)):
		out.append("adapter '%s' looks like a software rasteriser — this run cannot judge an fps floor"
			% str(env.get("video_adapter", "?")))
	# Skipped headless: the headless DisplayServer reports VSYNC_ENABLED whatever
	# it was set to, and there is no presentation for it to gate. Warning about a
	# cap that isn't there would be the same kind of confident-wrong reading this
	# report exists to prevent.
	if not headless and int(env.get("vsync_mode", 0)) != DisplayServer.VSYNC_DISABLED:
		var refresh_val = env.get("screen_refresh_rate")
		var refresh_hz: float = float(refresh_val) if refresh_val != null else 0.0
		out.append("vsync is on — fps is capped at the refresh rate (%.0f Hz) and headroom above it is invisible"
			% refresh_hz)
	if int(env.get("max_fps", 0)) > 0:
		out.append("Engine.max_fps is %d — the frame rate is capped below whatever the hardware could do"
			% int(env.get("max_fps", 0)))
	if not bool(_build_is_release()):
		out.append("debug build — GDScript runs unoptimised and slower than the pack a player downloads")
	if _frame_ms.size() < 60:
		out.append("only %d steady-state frames sampled — too few for a percentile to mean anything"
			% _frame_ms.size())
	if _dropped_samples > 0:
		out.append("%d frames past the sample cap were dropped" % _dropped_samples)
	if _time_scale_min < 0.999:
		out.append(("Engine.time_scale dipped to %.2f during this run (reward hitstop). "
			+ "Frame times and the window here are WALL clock and unaffected, but any "
			+ "in-game rate compared against them is in dilated seconds")
			% _time_scale_min)
	return out


func _build_is_release() -> bool:
	return not OS.is_debug_build()


func _verdict_line(report: Dictionary) -> String:
	var s: Dictionary = report.get("steady_state", {})
	if s.is_empty():
		return "no steady-state frames"
	return "fps mean %.1f / p50 %.1f / p1_low %.1f%s" % [
		float(s.get("fps_mean", 0.0)), float(s.get("fps_p50", 0.0)), float(s.get("fps_1pct_low", 0.0)),
		"" if bool(report.get("trustworthy", false)) else "  [NOT TRUSTWORTHY — see caveats]"]


static func _stats(samples: PackedFloat64Array) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in sorted:
		total += v
	var mean_ms := total / float(n)

	# Frame-time percentiles, then fps derived from them — NOT the mean of
	# per-frame fps, which flatters a stuttery run by weighting fast frames.
	# The high frame-time percentiles are the ones a player feels, so p95 frame
	# time is reported as the "1% low" fps the way a benchmark would.
	var over_33 := 0
	var over_50 := 0
	var over_100 := 0
	for v in sorted:
		if v > 33.4:
			over_33 += 1
		if v > 50.0:
			over_50 += 1
		if v > 100.0:
			over_100 += 1
	return {
		"frames": n,
		"frame_ms_mean": mean_ms,
		"frame_ms_p50": _percentile(sorted, 0.50),
		"frame_ms_p95": _percentile(sorted, 0.95),
		"frame_ms_p99": _percentile(sorted, 0.99),
		"frame_ms_max": sorted[n - 1],
		"frame_ms_min": sorted[0],
		"hitch_over_33ms": over_33,
		"hitch_over_50ms": over_50,
		"hitch_over_100ms": over_100,
		"fps_mean": (1000.0 / mean_ms) if mean_ms > 0.0 else 0.0,
		"fps_p50": _fps_from_ms(_percentile(sorted, 0.50)),
		"fps_1pct_low": _fps_from_ms(_percentile(sorted, 0.99)),
		"fps_min": _fps_from_ms(sorted[n - 1]),
	}


func _attribution() -> Dictionary:
	# Turn the cumulative batcher + viz ledgers into shares of WALL time so a
	# reader cannot mistake a per-packet average for "the frame". First/last
	# snapshots after warmup are the window; warmup boot cost stays out.
	var first_b: Dictionary = {}
	var last_b: Dictionary = {}
	var first_v: Dictionary = {}
	var last_v: Dictionary = {}
	for snap in _snapshots:
		if float(snap.get("t", 0.0)) < _warmup_s:
			continue
		var b: Dictionary = snap.get("batcher", {})
		if not b.is_empty():
			if first_b.is_empty():
				first_b = b
			last_b = b
		var v: Dictionary = snap.get("viz", {})
		if not v.is_empty():
			if first_v.is_empty():
				first_v = v
			last_v = v
	if first_b.is_empty() and first_v.is_empty():
		return {}
	var wall_ms := maxf(0.0, _elapsed - _warmup_s) * 1000.0
	if wall_ms <= 0.0:
		return {}
	var out := {
		"wall_ms": wall_ms,
		"clock": "wall",
	}
	var accounted := 0.0
	var batcher_keys := [
		"native_ms_total", "merge_ms_total", "take_ms_total", "consume_ms_total",
		"refill_ms_total", "poll_ms_total",
	]
	for key in batcher_keys:
		var delta: float = float(last_b.get(key, 0.0)) - float(first_b.get(key, 0.0))
		out[key.replace("_total", "_delta")] = delta
		out[key.replace("_ms_total", "_share")] = delta / wall_ms
		accounted += delta
	# Top-level viz seams. Sub-keys (viz_field3d_force, viz_farm_grid, …) are
	# subsets of these and must NOT also join accounted or the share exceeds 1.
	var viz_top := [
		"viz_field3d", "viz_force_process", "viz_force_draw",
		"viz_farm", "viz_pgd", "viz_farm_physics_rest", "viz_witness",
	]
	var viz_out := {}
	for key in last_v.keys():
		var delta_v: float = float(last_v.get(key, 0.0)) - float(first_v.get(key, 0.0))
		var share_v: float = delta_v / wall_ms
		viz_out[key + "_ms"] = delta_v
		viz_out[key + "_share"] = share_v
		if key in viz_top:
			accounted += delta_v
	out["viz"] = viz_out
	out["accounted_ms"] = accounted
	out["accounted_share"] = accounted / wall_ms
	out["unaccounted_share"] = 1.0 - (accounted / wall_ms)
	var packets: float = float(last_b.get("packets_total", 0.0)) - float(first_b.get("packets_total", 0.0))
	var steps: float = float(last_b.get("steps_total", 0.0)) - float(first_b.get("steps_total", 0.0))
	out["packets_delta"] = packets
	out["steps_delta"] = steps
	if steps > 0.0:
		out["native_ms_per_step"] = float(out.get("native_ms_delta", 0.0)) / steps
	# Godot's own last-frame monitors, accumulated. `engine_process` is main-thread
	# script + idle + render-submit. `present_wait` is wall minus that — vsync and
	# GPU wait. The 2026-08-14 unnamed 73% splits across these two.
	var first_e := 0.0
	var last_e := _engine_process_ms_total
	var first_p := 0.0
	var last_p := _engine_physics_ms_total
	var saw_e := false
	for snap2 in _snapshots:
		if float(snap2.get("t", 0.0)) < _warmup_s:
			continue
		if snap2.has("engine_process_ms_total"):
			if not saw_e:
				first_e = float(snap2["engine_process_ms_total"])
				first_p = float(snap2.get("engine_physics_ms_total", 0.0))
				saw_e = true
			last_e = float(snap2["engine_process_ms_total"])
			last_p = float(snap2.get("engine_physics_ms_total", 0.0))
	if saw_e:
		var eng := last_e - first_e
		var phy := last_p - first_p
		out["engine_process_ms"] = eng
		out["engine_process_share"] = eng / wall_ms
		out["engine_physics_ms"] = phy
		out["engine_physics_share"] = phy / wall_ms
		out["present_wait_ms"] = maxf(0.0, wall_ms - eng)
		out["present_wait_share"] = maxf(0.0, 1.0 - (eng / wall_ms))
		out["engine_minus_script_ms"] = maxf(0.0, eng - accounted)
		out["engine_minus_script_share"] = maxf(0.0, (eng - accounted) / wall_ms)
	return out


static func _fps_from_ms(ms: float) -> float:
	return (1000.0 / ms) if ms > 0.0 else 0.0


static func _percentile(sorted_samples: PackedFloat64Array, q: float) -> float:
	var n := sorted_samples.size()
	if n == 0:
		return 0.0
	var idx := int(round(q * float(n - 1)))
	return sorted_samples[clampi(idx, 0, n - 1)]


static func _write_json(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	return OK


func _post_web_report(data: Dictionary) -> Error:
	# The kit server exposes POST /__engine_perf on the same origin the page
	# loaded from. HTTPRequest so we do not have to JS-escape a 100 KB JSON body.
	if not OS.has_feature("web"):
		return ERR_UNAVAILABLE
	var origin := ""
	if ClassDB.class_exists("JavaScriptBridge"):
		origin = str(JavaScriptBridge.eval("String(window.location.origin || '')", true))
	if origin == "":
		return ERR_UNAVAILABLE
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(
		origin.rstrip("/") + "/__engine_perf",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data))
	if err != OK:
		http.queue_free()
		return err
	await http.request_completed
	http.queue_free()
	return OK
