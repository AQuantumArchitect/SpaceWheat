class_name BiomeDynamicsTracker
extends RefCounted

## Tracks quantum observable evolution rates over time
## Calculates dynamics: how fast the biome state is changing
##
## Usage:
##   tracker.add_snapshot(observables_dict)
##   var dynamics = tracker.get_dynamics()  # 0.0 = stable, 1.0 = volatile

class ObservableSnapshot:
	"""Single timestamped measurement of quantum observables"""
	var timestamp: float = 0.0  # Time.get_ticks_msec()
	var purity: float = 0.5
	var entropy: float = 0.5
	var coherence: float = 0.0

# Ring buffer of recent snapshots (last N samples)
var history: Array = []  # Array of ObservableSnapshot
var max_history_size: int = 20  # Track last 20 samples

# Throttling: only record snapshots at intervals
var min_snapshot_interval_ms: float = 100.0  # Min 100ms between snapshots
var last_snapshot_time: float = 0.0


func add_snapshot(obs: Dictionary) -> void:
	"""Record current observables with throttling

	Args:
		obs: Dictionary with keys "purity", "entropy", "coherence"
	"""
	var now = Time.get_ticks_msec()

	# Throttle: skip if too soon after last snapshot
	if now - last_snapshot_time < min_snapshot_interval_ms:
		return

	last_snapshot_time = now

	var snapshot = ObservableSnapshot.new()
	snapshot.timestamp = now
	snapshot.purity = obs.get("purity", 0.5)
	snapshot.entropy = obs.get("entropy", 0.5)
	snapshot.coherence = obs.get("coherence", 0.0)

	history.append(snapshot)

	# Keep only recent history (ring buffer behavior)
	if history.size() > max_history_size:
		history.pop_front()


func get_dynamics() -> float:
	"""Calculate evolution rate: average change per second across all observables

	Returns:
		float in [0, 1]: 0 = stable (slow changes), 1 = volatile (rapid fluctuations)
	"""
	if history.size() < 2:
		return 0.5  # Not enough data - neutral

	var total_rate = 0.0
	var count = 0

	# Compare each pair of consecutive snapshots
	for i in range(1, history.size()):
		var prev = history[i - 1]
		var curr = history[i]

		var dt = (curr.timestamp - prev.timestamp) / 1000.0  # Convert to seconds
		if dt < 0.01:  # Skip if too close (< 10ms)
			continue

		# Calculate change rates for each observable
		var dpurity = abs(curr.purity - prev.purity) / dt
		var dentropy = abs(curr.entropy - prev.entropy) / dt
		var dcoherence = abs(curr.coherence - prev.coherence) / dt

		total_rate += dpurity + dentropy + dcoherence
		count += 1

	if count == 0:
		return 0.5

	# Average rate of change, normalized to [0, 1]
	# Calibration: 0.5 change/sec is "medium" dynamics
	# (empirically determined from typical gameplay)
	var avg_rate = total_rate / count
	return clamp(avg_rate / 0.5, 0.0, 1.0)


func get_stability_label() -> String:
	"""Human-readable dynamics description for UI display"""
	var d = get_dynamics()

	if d < 0.2:
		return "Stable (slow changes)"
	elif d < 0.5:
		return "Moderate (steady evolution)"
	elif d < 0.8:
		return "Active (frequent changes)"
	else:
		return "Volatile (rapid fluctuations)"


func get_average_purity() -> float:
	"""Get average purity from recent history"""
	if history.is_empty():
		return 0.5

	var sum = 0.0
	for snapshot in history:
		sum += snapshot.purity

	return sum / history.size()


func get_average_entropy() -> float:
	"""Get average entropy from recent history"""
	if history.is_empty():
		return 0.5

	var sum = 0.0
	for snapshot in history:
		sum += snapshot.entropy

	return sum / history.size()


func get_average_coherence() -> float:
	"""Get average coherence from recent history"""
	if history.is_empty():
		return 0.0

	var sum = 0.0
	for snapshot in history:
		sum += snapshot.coherence

	return sum / history.size()


func clear_history() -> void:
	"""Reset tracker (useful for biome switches or major state changes)"""
	history.clear()
	last_snapshot_time = 0.0


func get_history_duration() -> float:
	"""Get time span of current history in seconds"""
	if history.size() < 2:
		return 0.0

	var oldest = history[0].timestamp
	var newest = history[-1].timestamp

	return (newest - oldest) / 1000.0
