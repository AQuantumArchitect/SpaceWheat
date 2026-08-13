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
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _warmup_frame_ms: PackedFloat64Array = PackedFloat64Array()
var _snapshots: Array[Dictionary] = []
var _next_snapshot_at: float = 0.0
var _written: bool = false

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

	# Sample after every other _process in the frame, so a snapshot reflects the
	# work the frame actually did rather than half of it.
	process_priority = 1000
	get_window().close_requested.connect(_on_close_requested)

	print("[PERF] sampling → %s (warmup %.1fs, duration %s, quit_when_done %s)" % [
		_log_path, _warmup_s,
		("%.1fs" % _duration_s) if _duration_s > 0.0 else "until quit",
		str(_quit_when_done)])


func _process(delta: float) -> void:
	_elapsed += delta

	var ms := delta * 1000.0
	if _elapsed < _warmup_s:
		# Kept, not discarded: boot cost is a real number a player pays, it just
		# is not the steady state the floor is about. Reported separately.
		_warmup_frame_ms.append(ms)
	elif _frame_ms.size() < _MAX_SAMPLES:
		_frame_ms.append(ms)
	else:
		_dropped_samples += 1

	if _elapsed >= _next_snapshot_at:
		_next_snapshot_at = _elapsed + _snapshot_interval_s
		_snapshots.append(_take_snapshot())

	if _duration_s > 0.0 and _elapsed >= _warmup_s + _duration_s:
		_finish("duration_reached")


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
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1_048_576.0,
	}
	var batcher := _resolve_batcher()
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
			"packets_total": m.get("packets_total", null),
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
	var err := _write_json(_log_path, report)
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
		},
		"steady_state": _stats(_frame_ms),
		"warmup": _stats(_warmup_frame_ms),
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
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
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
		out.append("vsync is on — fps is capped at the refresh rate (%.0f Hz) and headroom above it is invisible"
			% float(env.get("screen_refresh_rate", 0.0)))
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
	return {
		"frames": n,
		"frame_ms_mean": mean_ms,
		"frame_ms_p50": _percentile(sorted, 0.50),
		"frame_ms_p95": _percentile(sorted, 0.95),
		"frame_ms_p99": _percentile(sorted, 0.99),
		"frame_ms_max": sorted[n - 1],
		"frame_ms_min": sorted[0],
		"fps_mean": (1000.0 / mean_ms) if mean_ms > 0.0 else 0.0,
		"fps_p50": _fps_from_ms(_percentile(sorted, 0.50)),
		"fps_1pct_low": _fps_from_ms(_percentile(sorted, 0.99)),
		"fps_min": _fps_from_ms(sorted[n - 1]),
	}


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
