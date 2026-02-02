extends Node

## DetailedProfiler - Captures detailed performance metrics and exports to JSON
## Uses Godot's Performance class to get per-frame timing data

const SAMPLE_INTERVAL: int = 10  # Sample every N frames
const MAX_SAMPLES: int = 600  # 10 minutes at 60fps / 10
const OUTPUT_FILE: String = "/tmp/godot_detailed_profile.json"

var frame_count: int = 0
var samples: Array = []

# Performance monitors to track (Godot 4.5 compatible)
var MONITORS = {
	"time_fps": Performance.TIME_FPS,
	"time_process": Performance.TIME_PROCESS,
	"time_physics": Performance.TIME_PHYSICS_PROCESS,
	"memory_static": Performance.MEMORY_STATIC,
	"object_count": Performance.OBJECT_COUNT,
	"object_node_count": Performance.OBJECT_NODE_COUNT,
	"object_orphan_node_count": Performance.OBJECT_ORPHAN_NODE_COUNT,
}


func _ready() -> void:
	set_process(true)
	print("[DetailedProfiler] Started profiling - will sample every %d frames" % SAMPLE_INTERVAL)
	print("[DetailedProfiler] Output will be saved to: %s" % OUTPUT_FILE)


func _process(_delta: float) -> void:
	frame_count += 1

	# Sample every SAMPLE_INTERVAL frames
	if frame_count % SAMPLE_INTERVAL != 0:
		return

	# Collect all monitor data
	var sample = {
		"frame": frame_count,
		"timestamp": Time.get_ticks_msec(),
	}

	for monitor_name in MONITORS:
		var value = Performance.get_monitor(MONITORS[monitor_name])
		sample[monitor_name] = value

	samples.append(sample)

	# Print to console every 100 samples
	if samples.size() % 100 == 0:
		print("[DetailedProfiler] Collected %d samples (frame %d)" % [samples.size(), frame_count])

	# Stop after MAX_SAMPLES and export
	if samples.size() >= MAX_SAMPLES:
		_export_and_quit()


func _export_and_quit() -> void:
	"""Export collected data to JSON and quit."""
	print("[DetailedProfiler] Exporting %d samples to %s..." % [samples.size(), OUTPUT_FILE])

	# Calculate statistics
	var stats = _calculate_statistics()

	var output_data = {
		"total_frames": frame_count,
		"total_samples": samples.size(),
		"sample_interval": SAMPLE_INTERVAL,
		"statistics": stats,
		"samples": samples
	}

	# Write to file
	var file = FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(output_data, "\t"))
		file.close()
		print("[DetailedProfiler] ✅ Profile data exported successfully!")
	else:
		print("[DetailedProfiler] ❌ ERROR: Could not open file for writing")

	# Quit after 1 second
	await get_tree().create_timer(1.0).timeout
	print("[DetailedProfiler] Quitting...")
	get_tree().quit()


func _calculate_statistics() -> Dictionary:
	"""Calculate min/max/avg for all monitored metrics."""
	var stats = {}

	# Initialize stats dict
	for monitor_name in MONITORS:
		stats[monitor_name] = {
			"min": INF,
			"max": -INF,
			"avg": 0.0,
			"sum": 0.0
		}

	# Calculate
	for sample in samples:
		for monitor_name in MONITORS:
			var value = sample.get(monitor_name, 0.0)
			stats[monitor_name]["min"] = minf(stats[monitor_name]["min"], value)
			stats[monitor_name]["max"] = maxf(stats[monitor_name]["max"], value)
			stats[monitor_name]["sum"] += value

	# Calculate averages
	for monitor_name in stats:
		stats[monitor_name]["avg"] = stats[monitor_name]["sum"] / samples.size()

	return stats
