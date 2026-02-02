extends Node

## UIPerformanceTracker - Global singleton for tracking UI component performance
## Collects timing data from all UI components to identify bottlenecks

# Per-component timing samples (last 100 frames)
var component_samples: Dictionary = {}
const MAX_SAMPLES = 100

func _ready() -> void:
	print("[UIPerformanceTracker] Initialized - tracking UI component performance")

func record_time(component_name: String, time_us: float) -> void:
	"""Record timing for a component (in microseconds)."""
	if not component_samples.has(component_name):
		component_samples[component_name] = []
		print("[UIPerformanceTracker] Started tracking: %s" % component_name)

	var samples = component_samples[component_name]
	samples.append(time_us)

	# Keep only last MAX_SAMPLES
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()

	# Debug: print first few recordings
	if samples.size() <= 3:
		print("[UIPerformanceTracker] %s: %.2f us" % [component_name, time_us])

func get_average_ms(component_name: String) -> float:
	"""Get average time in milliseconds for a component."""
	if not component_samples.has(component_name):
		return 0.0

	var samples = component_samples[component_name]
	if samples.is_empty():
		return 0.0

	var total = 0.0
	for s in samples:
		total += s

	return (total / samples.size()) / 1000.0  # Convert to ms

func get_all_averages() -> Dictionary:
	"""Get averages for all tracked components."""
	var averages = {}
	for component in component_samples.keys():
		averages[component] = get_average_ms(component)
	return averages

func print_report() -> void:
	"""Print performance report to console."""
	var averages = get_all_averages()
	if averages.is_empty():
		return

	print("\n[UI_PERF] ═══════════════════════════════════════")
	print("[UI_PERF] UI Component Performance Report")
	print("[UI_PERF] ═══════════════════════════════════════")

	# Sort by time (highest first)
	var sorted_components = averages.keys()
	sorted_components.sort_custom(func(a, b): return averages[a] > averages[b])

	var total = 0.0
	for component in sorted_components:
		var time_ms = averages[component]
		total += time_ms
		var bar_length = int(time_ms / 2.0)  # 1 char = 2ms
		var bar = "█".repeat(bar_length)
		print("[UI_PERF] %25s: %6.2fms %s" % [component, time_ms, bar])

	print("[UI_PERF] %25s: %6.2fms" % ["TOTAL", total])
	print("[UI_PERF] ═══════════════════════════════════════\n")
