class_name BiomeTimeTracker
extends RefCounted

## Manages time tracking and periodic events for biomes
## Composition pattern - biomes own an instance instead of duplicating code

var time_elapsed: float = 0.0
var period: float = 20.0  # Default sun/moon period (seconds)

signal period_complete(cycle_count: int)
signal checkpoint_reached(time: float)

var cycle_count: int = 0
var checkpoints: Array[float] = []


func update(delta: float) -> void:
	"""Update time tracker each frame"""
	time_elapsed += delta

	# Check for period completion
	if time_elapsed >= period and period > 0:
		cycle_count += 1
		period_complete.emit(cycle_count)
		time_elapsed = fmod(time_elapsed, period)

	# Check for checkpoints (not used by default, but available)
	if checkpoints.size() > 0:
		var completed: Array[float] = []
		for checkpoint in checkpoints:
			if time_elapsed >= checkpoint:
				checkpoint_reached.emit(checkpoint)
				completed.append(checkpoint)
		# Remove completed checkpoints
		for cp in completed:
			checkpoints.erase(cp)


func get_cycle_progress() -> float:
	"""Returns 0.0 to 1.0 progress through current cycle"""
	return time_elapsed / period if period > 0 else 0.0


func add_checkpoint(time: float) -> void:
	"""Add a time checkpoint (for periodic events)"""
	if time not in checkpoints:
		checkpoints.append(time)


func reset() -> void:
	"""Reset time tracker to initial state"""
	time_elapsed = 0.0
	cycle_count = 0
	checkpoints.clear()
